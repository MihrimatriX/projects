using System.Diagnostics;
using InputSimulatorStandard.Native;
using Microsoft.Data.Sqlite;
using OtomasyonMakro.Models;
using OtomasyonMakro.Services;
using Xunit;

namespace OtomasyonMakro.Tests;

/// <summary>Gerçek masaüstüne hiçbir girdi göndermeyen sahte giriş: yalnızca çağrıları kaydeder.</summary>
public sealed class FakeInput : IMacroInput
{
    public List<string> Calls { get; } = new();
    public string ForegroundTitle { get; set; } = "Adsız - Not Defteri";
    public string? ForegroundProcess { get; set; } = "notepad";
    public Action<FakeInput>? OnAction { get; set; }

    private void Log(string call)
    {
        Calls.Add(call);
        OnAction?.Invoke(this);
    }

    public void MoveCursor(int x, int y) => Log($"move {x},{y}");
    public void LeftClick() => Log("click");
    public void TypeText(string text) => Log($"type {text}");
    public void PressKey(VirtualKeyCode key) => Log($"key {key}");
    public void ClickUiElement(string? name, string? automationId, string? className) => Log($"ui {name}/{automationId}");
    public string GetForegroundWindowTitle() => ForegroundTitle;
    public string? GetForegroundProcessName() => ForegroundProcess;
}

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "makro-test-" + Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public string Combine(params string[] parts) => System.IO.Path.Combine([Path, .. parts]);
    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        try { Directory.Delete(Path, true); } catch (IOException) { }
    }
}

public class PlaybackServiceTests
{
    private static MacroProfile Profile(params MacroStep[] steps)
    {
        var p = new MacroProfile { Name = "test", TargetProcessName = MacroProfile.FocusOnlyTarget };
        for (int i = 0; i < steps.Length; i++) { steps[i].Sequence = i + 1; p.Steps.Add(steps[i]); }
        return p;
    }

    private static (PlaybackService svc, FakeInput input, List<string> events) Create()
    {
        var input = new FakeInput();
        var svc = new PlaybackService(input);
        var events = new List<string>();
        svc.OnFinished += () => events.Add("finished");
        svc.OnCancelled += () => events.Add("cancelled");
        svc.OnError += m => events.Add("error: " + m);
        svc.OnIterationStarted += i => events.Add("iteration " + i);
        return (svc, input, events);
    }

    [Fact]
    public async Task Plays_click_text_key_and_ui_steps_in_order()
    {
        var (svc, input, events) = Create();
        var profile = Profile(
            new MacroStep { ActionType = MacroActionType.MouseClick, MouseX = 10, MouseY = 20 },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "Merhaba {{user}}" },
            new MacroStep { ActionType = MacroActionType.TextDelay, DelayMs = 10 },
            new MacroStep { ActionType = MacroActionType.KeyPress, Text = "ENTER" },
            new MacroStep { ActionType = MacroActionType.UiElementClick, UiElementName = "Tamam", UiAutomationId = "ok" });

        await svc.PlayAsync(profile, CancellationToken.None);

        Assert.Equal(new[] { "move 10,20", "click", $"type Merhaba {Environment.UserName}", "key RETURN", "ui Tamam/ok" }, input.Calls);
        Assert.Equal(new[] { "iteration 1", "finished" }, events);
    }

    [Fact]
    public async Task If_window_title_jumps_when_title_does_not_match()
    {
        var (svc, input, _) = Create();
        var profile = Profile(
            new MacroStep { ActionType = MacroActionType.IfWindowTitle, Text = "Not Defteri", JumpToSequence = 3 },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "eşleşti" },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "son" });

        await svc.PlayAsync(profile, CancellationToken.None);
        Assert.Equal(new[] { "type eşleşti", "type son" }, input.Calls);

        input.Calls.Clear();
        input.ForegroundTitle = "Hesap Makinesi";
        await svc.PlayAsync(profile, CancellationToken.None);
        Assert.Equal(new[] { "type son" }, input.Calls);
    }

    [Fact]
    public async Task Repeat_count_plays_profile_n_times()
    {
        var (svc, input, events) = Create();
        var profile = Profile(new MacroStep { ActionType = MacroActionType.KeyPress, Text = "TAB" });
        profile.RepeatCount = 3;

        await svc.PlayAsync(profile, CancellationToken.None);

        Assert.Equal(3, input.Calls.Count);
        Assert.Equal(new[] { "iteration 1", "iteration 2", "iteration 3", "finished" }, events);
    }

    [Fact]
    public async Task Emergency_stop_interrupts_long_delay_and_sends_nothing_after()
    {
        var (svc, input, events) = Create();
        var profile = Profile(
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "önce" },
            new MacroStep { ActionType = MacroActionType.TextDelay, DelayMs = 60_000 },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "sonra" });

        using var cts = new CancellationTokenSource();
        var sw = Stopwatch.StartNew();
        var play = svc.PlayAsync(profile, cts.Token);
        await Task.Delay(100);
        cts.Cancel(); // EmergencyStopMonitor'ün ESC'de yaptığı şey
        await play;

        Assert.True(sw.Elapsed < TimeSpan.FromSeconds(5), "Bekleme adımı acil durdurmada beklemeye devam etti");
        Assert.Equal(new[] { "type önce" }, input.Calls);
        Assert.Equal("cancelled", events[^1]);
        Assert.DoesNotContain(events, e => e.StartsWith("error") || e == "finished");
    }

    [Fact]
    public async Task Endless_repeat_stops_on_cancel()
    {
        var (svc, input, events) = Create();
        using var cts = new CancellationTokenSource();
        input.OnAction = f => { if (f.Calls.Count == 5) cts.Cancel(); };
        var profile = Profile(new MacroStep { ActionType = MacroActionType.KeyPress, Text = "SPACE" });
        profile.RepeatCount = 0;

        var play = svc.PlayAsync(profile, cts.Token);
        Assert.Same(play, await Task.WhenAny(play, Task.Delay(5000)));

        Assert.Equal(5, input.Calls.Count);
        Assert.Equal("cancelled", events[^1]);
    }

    [Fact]
    public async Task Jump_only_loop_can_be_cancelled()
    {
        var (svc, input, events) = Create();
        var profile = Profile(new MacroStep { ActionType = MacroActionType.JumpToStep, JumpToSequence = 1 });
        using var cts = new CancellationTokenSource(200);

        var play = svc.PlayAsync(profile, cts.Token);
        Assert.Same(play, await Task.WhenAny(play, Task.Delay(5000)));
        Assert.Empty(input.Calls);
        Assert.Equal("cancelled", events[^1]);
    }

    [Theory]
    [InlineData("chrome", "Güvenli Mod Koruması")]
    [InlineData(null, "Odaklanmış herhangi bir pencere bulunamadı")]
    public async Task Safety_lock_blocks_input_to_wrong_window(string? foreground, string expectedError)
    {
        var (svc, input, events) = Create();
        input.ForegroundProcess = foreground;
        var profile = Profile(new MacroStep { ActionType = MacroActionType.WriteText, Text = "gizli" });
        profile.TargetProcessName = "notepad";

        await svc.PlayAsync(profile, CancellationToken.None);

        Assert.Empty(input.Calls);
        Assert.Contains(events, e => e.Contains(expectedError));
    }

    [Fact]
    public async Task Unknown_key_stops_with_error_instead_of_silently_skipping()
    {
        var (svc, input, events) = Create();
        var profile = Profile(
            new MacroStep { ActionType = MacroActionType.KeyPress, Text = "OLMAYANTUS" },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "x" });

        await svc.PlayAsync(profile, CancellationToken.None);

        Assert.Empty(input.Calls);
        Assert.Contains(events, e => e.Contains("bilinmeyen tuş"));
    }

    [Fact]
    public async Task Single_step_plays_only_that_step()
    {
        var (svc, input, events) = Create();
        var profile = Profile(
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "1" },
            new MacroStep { ActionType = MacroActionType.WriteText, Text = "2" });

        await svc.PlayStepAsync(profile, 1, CancellationToken.None);

        Assert.Equal(new[] { "type 2" }, input.Calls);
        Assert.DoesNotContain("finished", events);
    }

    [Theory]
    [InlineData(0x0D)] // RETURN
    [InlineData(0xBE)] // OEM_PERIOD
    [InlineData(0x21)] // PRIOR (Page Up)
    [InlineData(0x74)] // F5
    [InlineData(0x2E)] // DELETE
    public void Recorded_key_names_round_trip_to_same_virtual_key(uint vk)
    {
        Assert.Equal((VirtualKeyCode)vk, PlaybackService.ParseKeyCode(MacroRecorder.KeyName(vk)));
    }

    [Theory]
    [InlineData("ENTER", VirtualKeyCode.RETURN)]
    [InlineData("backspace", VirtualKeyCode.BACK)]
    [InlineData("OEMPERIOD", VirtualKeyCode.OEM_PERIOD)] // eski sürüm (WPF Key adı) kayıtları
    [InlineData("PAGEUP", VirtualKeyCode.PRIOR)]
    [InlineData("D1", VirtualKeyCode.VK_1)]
    [InlineData("A", VirtualKeyCode.VK_A)]
    [InlineData("13", VirtualKeyCode.NONAME)]
    public void ParseKeyCode_accepts_friendly_and_legacy_names(string text, VirtualKeyCode expected)
    {
        Assert.Equal(expected, PlaybackService.ParseKeyCode(text));
    }

    [Fact]
    public void Emergency_key_is_physical_escape_only()
    {
        Assert.True(EmergencyStopMonitor.IsEmergencyKey(0x1B, 0));
        Assert.False(EmergencyStopMonitor.IsEmergencyKey(0x1B, 0x10)); // makronun kendi gönderdiği ESC
        Assert.False(EmergencyStopMonitor.IsEmergencyKey(0x41, 0));
    }
}

public class MacroRecorderTests
{
    private long _now = 1000;
    private readonly List<MacroStep> _steps = new();
    private readonly MacroRecorder _rec;

    public MacroRecorderTests()
    {
        _rec = new MacroRecorder(() => _now);
        _rec.OnStepRecorded += _steps.Add;
    }

    private string Dump() => string.Join(" | ", _steps.Select(s => s.ActionType switch
    {
        MacroActionType.TextDelay => $"wait {s.DelayMs}",
        MacroActionType.WriteText => $"text {s.Text}",
        MacroActionType.KeyPress => $"key {s.Text}",
        MacroActionType.MouseClick => $"click {s.MouseX},{s.MouseY}",
        _ => s.ActionType.ToString()
    }));

    private void Type(uint vk, bool shift = false, int afterMs = 10)
    {
        _rec.KeyDown(vk, shift, capsLock: false, ctrlOrAlt: false);
        _now += afterMs;
    }

    [Fact]
    public void Typing_is_buffered_into_one_text_step_with_preceding_wait()
    {
        _now += 700;
        Type(0x41, shift: true); // A
        Type(0x42);             // b
        Type(0x20);             // space
        Type(0x31);             // 1
        _now += 300;
        _rec.MouseDown(5, 6);
        _rec.Flush();

        Assert.Equal("wait 700 | text Ab 1 | wait 310 | click 5,6", Dump()); // son tuştan (1730) tıklamaya (2040)
    }

    [Fact]
    public void Special_keys_flush_text_and_round_trip_names()
    {
        Type(0x48); // h
        Type(0x0D); // Enter
        Type(0x10); // Shift tek başına kaydedilmez
        Type(0xBE); // nokta (OEM)

        Assert.Equal("text h | key RETURN | key OEM_PERIOD", Dump());
    }

    [Fact]
    public void Escape_and_ctrl_alt_shortcuts_are_not_recorded()
    {
        _rec.KeyDown(0x1B, false, false, ctrlOrAlt: false); // ESC (acil durdurma)
        _rec.KeyDown(0x4D, false, false, ctrlOrAlt: true);  // Ctrl+Alt+M (kayıt kısayolu)
        _rec.Flush();
        Assert.Empty(_steps);
    }

    [Fact]
    public void Paused_time_and_events_are_not_recorded()
    {
        Type(0x41);
        _rec.IsPaused = true;      // duraklatırken tampon yazılır
        Type(0x42);
        _rec.MouseDown(1, 1);
        _now += 60_000;
        _rec.IsPaused = false;
        _now += 20;
        _rec.MouseDown(2, 2);

        Assert.Equal("text a | click 2,2", Dump());
    }
}

public class ProfileAndDatabaseTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void RenumberSteps_keeps_jump_targets_on_moved_steps_and_clears_deleted_targets()
    {
        var p = new MacroProfile();
        var jump = new MacroStep { ActionType = MacroActionType.JumpToStep, JumpToSequence = 3 };
        var a = new MacroStep { ActionType = MacroActionType.WriteText, Text = "a" };
        var target = new MacroStep { ActionType = MacroActionType.WriteText, Text = "hedef" };
        foreach (var s in new[] { jump, a, target }) { s.Sequence = p.Steps.Count + 1; p.Steps.Add(s); }
        p.RenumberSteps();

        p.Steps.Move(2, 1); // hedef yukarı taşındı
        p.RenumberSteps();
        Assert.Equal(2, target.Sequence);
        Assert.Equal(2, jump.JumpToSequence);

        p.Steps.Remove(target);
        p.RenumberSteps();
        Assert.Equal(0, jump.JumpToSequence);
    }

    [Fact]
    public void New_database_is_seeded_and_profiles_round_trip()
    {
        var db = new DatabaseService(_tmp.Path);
        Assert.Equal(2, db.GetProfiles().Count);

        var p = new MacroProfile { Name = "Rapor", Hotkey = "Ctrl+Alt+R", RepeatCount = 4, ScheduleEnabled = true, ScheduleTime = "08:30" };
        p.Steps.Add(new MacroStep { ActionType = MacroActionType.WriteText, Text = "{{date}}", DelayMs = 100 });
        p.Steps.Add(new MacroStep { ActionType = MacroActionType.IfWindowTitle, Text = "Excel", JumpToSequence = 1 });
        db.SaveProfile(p);
        Assert.NotEqual(0, p.Id);

        var loaded = new DatabaseService(_tmp.Path).GetProfiles().Single(x => x.Id == p.Id);
        Assert.Equal(MacroProfile.Snapshot([p]), MacroProfile.Snapshot([loaded]));
        Assert.Equal(4, loaded.RepeatCount);

        loaded.Steps.RemoveAt(0);
        db.SaveProfile(loaded);
        var again = db.GetProfiles().Single(x => x.Id == p.Id);
        Assert.Single(again.Steps);
        Assert.Equal(0, again.Steps[0].JumpToSequence); // silinen adıma atlama temizlendi

        db.DeleteProfile(p.Id);
        Assert.DoesNotContain(db.GetProfiles(), x => x.Id == p.Id);
    }

    [Fact]
    public void Snapshot_detects_unsaved_edits()
    {
        var db = new DatabaseService(_tmp.Path);
        var inMemory = db.GetProfiles();
        Assert.Equal(MacroProfile.Snapshot(inMemory), MacroProfile.Snapshot(db.GetProfiles()));

        inMemory[0].Steps.Add(new MacroStep { ActionType = MacroActionType.KeyPress, Text = "TAB", Sequence = 99 });
        Assert.NotEqual(MacroProfile.Snapshot(inMemory), MacroProfile.Snapshot(db.GetProfiles()));
    }

    [Fact]
    public void Legacy_database_next_to_exe_is_migrated_once()
    {
        var legacy = _tmp.Combine("eski");
        var oldDb = new DatabaseService(legacy);
        oldDb.SaveProfile(new MacroProfile { Name = "Eski makro" });
        SqliteConnection.ClearAllPools();

        var target = _tmp.Combine("yeni");
        DatabaseService.MigrateLegacyData(legacy, target);
        Assert.Contains(new DatabaseService(target).GetProfiles(), p => p.Name == "Eski makro");
    }

    [Fact]
    public void Data_dir_env_override()
    {
        var old = Environment.GetEnvironmentVariable(DatabaseService.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, _tmp.Path);
            Assert.Equal(_tmp.Path, DatabaseService.ResolveDataFolder());
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, null);
            Assert.Equal(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OtomasyonMakro"),
                DatabaseService.ResolveDataFolder());
        }
        finally { Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, old); }
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir()
    {
        // Kullanıcının açık bir örneği varsa (global kısayollar ona ait) atla.
        if (Process.GetProcessesByName("OtomasyonMakro").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "OtomasyonMakro.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment[DatabaseService.DataDirEnvVar] = _tmp.Path;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandı");
            Assert.True(File.Exists(_tmp.Combine("macros.db")), "Veri klasörü ortam değişkeniyle değiştirilemedi");
            Assert.False(File.Exists(_tmp.Combine("crash.log")), "Açılışta yakalanmayan hata oluştu");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}
