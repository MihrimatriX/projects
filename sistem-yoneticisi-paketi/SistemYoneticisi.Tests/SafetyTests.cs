using System.Diagnostics;
using System.Runtime.CompilerServices;
using Microsoft.Win32;
using SistemYoneticisi.Services;
using Xunit;

namespace SistemYoneticisi.Tests;

internal static class TestDataDir
{
    public static readonly string Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"syp-tests-{Guid.NewGuid():N}");

    // Testler kullanıcının gerçek %LOCALAPPDATA%\SistemYoneticisiPaketi verisine (ayarlar, log, yedek) asla yazmamalı.
    [ModuleInitializer]
    internal static void Init()
    {
        Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, Path);
        AppDomain.CurrentDomain.ProcessExit += (_, _) => { try { Directory.Delete(Path, true); } catch { } };
    }
}

internal sealed class TempDir : IDisposable
{
    public string Path { get; } = Directory.CreateDirectory(
        System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"syp-{Guid.NewGuid():N}")).FullName;
    public string Combine(params string[] parts) => System.IO.Path.Combine([Path, .. parts]);
    public void Dispose() { try { Directory.Delete(Path, true); } catch { } }
}

public class DataDirTests
{
    [Fact]
    public void AppData_dir_is_overridden_by_env_var_in_tests()
    {
        Assert.Equal(TestDataDir.Path, AppPaths.AppDataDir);
        Assert.StartsWith(TestDataDir.Path, AppPaths.SettingsFile);
        Assert.StartsWith(TestDataDir.Path, AppPaths.StartupBackupDir);
    }
}

public class ProcessSafetyTests
{
    [Theory]
    [InlineData("csrss")]
    [InlineData("LSASS")]
    [InlineData("svchost")]
    [InlineData("dwm")]
    [InlineData("winlogon")]
    public void Critical_processes_are_protected(string name) =>
        Assert.True(ProcessService.IsProtectedProcess(5000, name, @"C:\Windows\System32\x.exe"));

    [Fact]
    public void Low_pids_own_process_and_inaccessible_processes_are_protected()
    {
        Assert.True(ProcessService.IsProtectedProcess(4, "anything", "x"));
        Assert.True(ProcessService.IsProtectedProcess(Environment.ProcessId, "testhost", "x"));
        Assert.True(ProcessService.IsProtectedProcess(5000, "unknown", ProcessService.AccessDenied));
        Assert.False(ProcessService.IsProtectedProcess(5000, "notepad", @"C:\Windows\notepad.exe"));
    }

    [Fact]
    public void KillProcess_refuses_own_process()
    {
        Assert.False(new ProcessService().KillProcess(Environment.ProcessId));
    }

    [Fact]
    public void KillProcess_kills_a_process_tree_started_by_the_test()
    {
        // Yalnızca testin kendi başlattığı zararsız süreç sonlandırılır.
        var psi = new ProcessStartInfo("cmd.exe", "/c ping -n 60 127.0.0.1 >nul")
        {
            UseShellExecute = false,
            CreateNoWindow = true
        };
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.True(new ProcessService().KillProcess(proc.Id));
            Assert.True(proc.WaitForExit(5000));
        }
        finally
        {
            if (!proc.HasExited) proc.Kill(true);
        }
    }

    [Fact]
    public void ToCsv_writes_header_and_escapes_quotes()
    {
        var csv = ProcessService.ToCsv([
            new ProcessInfo { Pid = 42, Name = "app", CpuPercentage = 1.5, MemoryMb = 10.2, Description = "say \"hi\"", Path = @"C:\a;b\app.exe" }
        ]);
        var lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal("PID;Ad;CPU %;RAM MB;Açıklama;Yol", lines[0]);
        Assert.Equal("42;\"app\";1.5;10.2;\"say \"\"hi\"\"\";\"C:\\a;b\\app.exe\"", lines[1]);
    }
}

public class ServiceSafetyTests
{
    [Theory]
    [InlineData("RpcSs", true)]
    [InlineData("rpcss", true)]
    [InlineData("WinDefend", true)]
    [InlineData("Winmgmt", true)]
    [InlineData("Spooler", false)]
    public void Critical_services_are_detected(string name, bool expected)
    {
        Assert.Equal(expected, ServiceManagerService.IsCriticalService(name));
        Assert.Equal(expected, new WindowsServiceInfo { Name = name, DisplayName = "X" }.IsCritical);
    }

    [Fact]
    public void Stop_and_restart_refuse_critical_services_without_calling_windows()
    {
        // Koruma WMI çağrısından önce döner; gerçek servise dokunulmaz.
        var svc = new ServiceManagerService();
        Assert.False(svc.StopService("RpcSs"));
        Assert.False(svc.RestartService("DcomLaunch"));
    }

    [Fact]
    public void Critical_service_list_name_has_lock()
    {
        Assert.StartsWith("🔒", new WindowsServiceInfo { Name = "EventLog", DisplayName = "Windows Event Log" }.ListName);
        Assert.Equal("Yazdırma", new WindowsServiceInfo { Name = "Spooler", DisplayName = "Yazdırma" }.ListName);
    }
}

public class StartupBackupTests : IDisposable
{
    // Gerçek Run anahtarı ve Başlangıç klasörü yerine geçici klasörler ve test anahtarı kullanılır.
    private const string TestRoot = @"Software\SistemYoneticisiPaketi.Tests";
    private readonly string _runKey = $@"{TestRoot}\{Guid.NewGuid():N}";
    private readonly TempDir _tmp = new();

    public void Dispose()
    {
        try { Registry.CurrentUser.DeleteSubKeyTree(_runKey, false); } catch { }
        try
        {
            using var root = Registry.CurrentUser.OpenSubKey(TestRoot);
            if (root != null && root.SubKeyCount == 0 && root.ValueCount == 0)
                Registry.CurrentUser.DeleteSubKey(TestRoot, false);
        }
        catch { }
        _tmp.Dispose();
    }

    private StartupService CreateService() =>
        new(_runKey, _tmp.Combine("user-startup"), _tmp.Combine("common-startup"), _tmp.Combine("backup"));

    [Fact]
    public void Folder_item_is_moved_to_backup_and_restored()
    {
        var userDir = Directory.CreateDirectory(_tmp.Combine("user-startup")).FullName;
        var lnk = Path.Combine(userDir, "Uygulama.lnk");
        File.WriteAllText(lnk, "shortcut");
        File.WriteAllText(Path.Combine(userDir, "desktop.ini"), "[.ShellClassInfo]");
        var svc = CreateService();

        var item = Assert.Single(svc.GetStartupItems());
        Assert.Equal("Uygulama", item.Name);
        Assert.True(item.IsCurrentUser);

        Assert.True(svc.RemoveStartupItem(item));
        Assert.False(File.Exists(lnk));
        Assert.Empty(svc.GetStartupItems());
        Assert.True(svc.HasRemovedItems);

        Assert.Equal("Uygulama", svc.RestoreLastRemoved());
        Assert.Equal("shortcut", File.ReadAllText(lnk));
        Assert.False(svc.HasRemovedItems);
        Assert.Null(svc.RestoreLastRemoved());
    }

    [Fact]
    public void Restore_does_not_overwrite_an_item_recreated_with_the_same_name()
    {
        var userDir = Directory.CreateDirectory(_tmp.Combine("user-startup")).FullName;
        var lnk = Path.Combine(userDir, "A.lnk");
        File.WriteAllText(lnk, "old");
        var svc = CreateService();
        Assert.True(svc.RemoveStartupItem(svc.GetStartupItems()[0]));

        File.WriteAllText(lnk, "new");
        Assert.Null(svc.RestoreLastRemoved());
        Assert.Equal("new", File.ReadAllText(lnk));
        Assert.True(svc.HasRemovedItems); // yedek korunur
    }

    [Fact]
    public void Registry_item_is_backed_up_and_restored_with_its_value_kind()
    {
        using (var key = Registry.CurrentUser.CreateSubKey(_runKey))
            key.SetValue("TestApp", @"%WINDIR%\notepad.exe", RegistryValueKind.ExpandString);
        var svc = CreateService();

        var item = Assert.Single(svc.GetStartupItems(), i => i.ItemType == StartupItemType.Registry && i.IsCurrentUser);
        Assert.True(svc.RemoveStartupItem(item));
        using (var key = Registry.CurrentUser.OpenSubKey(_runKey)!)
            Assert.Null(key.GetValue("TestApp"));

        Assert.Equal("TestApp", svc.RestoreLastRemoved());
        using (var key = Registry.CurrentUser.OpenSubKey(_runKey)!)
        {
            Assert.Equal(RegistryValueKind.ExpandString, key.GetValueKind("TestApp"));
            Assert.Equal(@"%WINDIR%\notepad.exe",
                key.GetValue("TestApp", null, RegistryValueOptions.DoNotExpandEnvironmentNames));
        }
    }

    [Fact]
    public void Removing_a_missing_item_fails_and_records_no_backup()
    {
        var svc = CreateService();
        Assert.False(svc.RemoveStartupItem(new StartupItem
        {
            Name = "Yok", ItemType = StartupItemType.Folder, FilePath = _tmp.Combine("yok.lnk"), IsCurrentUser = true
        }));
        Assert.False(svc.RemoveStartupItem(new StartupItem { Name = "Yok", ItemType = StartupItemType.Registry, IsCurrentUser = true }));
        Assert.False(svc.HasRemovedItems);
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir_and_stays_up()
    {
        // Kullanıcının açık bir örneği varsa (tek örnek mutex'i) atla.
        if (Process.GetProcessesByName("SistemYoneticisiPaketi").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "SistemYoneticisiPaketi.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment[AppPaths.DataDirEnvVar] = _tmp.Path;
        using var proc = Process.Start(psi)!;
        try
        {
            var log = _tmp.Combine("app.log");
            var sw = Stopwatch.StartNew();
            while (sw.Elapsed < TimeSpan.FromSeconds(30) && !proc.HasExited
                   && !(File.Exists(log) && ReadShared(log).Contains("MainViewModel initialized.")))
                Thread.Sleep(250);

            Assert.True(File.Exists(log), "Veri klasörü geçersiz kılınamadı");
            Assert.Contains("MainViewModel initialized.", ReadShared(log));
            Assert.False(proc.WaitForExit(3000), "Uygulama erken kapandı");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }

    private static string ReadShared(string path)
    {
        try
        {
            using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            return new StreamReader(fs).ReadToEnd();
        }
        catch (IOException) { return string.Empty; }
    }
}
