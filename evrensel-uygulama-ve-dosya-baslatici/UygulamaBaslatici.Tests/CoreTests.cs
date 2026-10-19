using System.Diagnostics;
using System.IO;
using UygulamaBaslatici.Services;
using UygulamaBaslatici.ViewModels;
using Xunit;

namespace UygulamaBaslatici.Tests;

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "komutpaleti-test-" + Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public string Combine(params string[] parts) => System.IO.Path.Combine([Path, .. parts]);
    public void Dispose() { try { Directory.Delete(Path, true); } catch (IOException) { } }
}

public class DatabaseServiceTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    private static AppScannerData App(string name, string path) => new() { Name = name, Path = path, Type = "App" };

    [Fact]
    public void Search_finds_substring_and_ranks_by_usage()
    {
        var db = new DatabaseService(_tmp.Path);
        db.BulkInsertApps([App("Notepad++", @"C:\a\npp.lnk"), App("Notepad", @"C:\a\np.lnk"), App("Paint", @"C:\a\p.lnk")]);

        Assert.Equal(["Notepad", "Notepad++"], db.SearchApps("note").Select(a => a.Name));

        db.IncrementUsage(@"C:\a\npp.lnk");
        var hits = db.SearchApps("pad");
        Assert.Equal("Notepad++", hits[0].Name);
        Assert.Equal(1, hits[0].UsageCount);
        Assert.Empty(db.SearchApps("  "));
        Assert.Equal("Notepad++", db.GetTopApps(1).Single().Name);
    }

    [Fact]
    public void Like_wildcards_in_query_are_literal()
    {
        var db = new DatabaseService(_tmp.Path);
        db.BulkInsertApps([App("100% Orange", @"C:\a\o.lnk"), App("Word", @"C:\a\w.lnk"), App("my_app", @"C:\a\m.lnk")]);

        Assert.Equal("100% Orange", Assert.Single(db.SearchApps("%")).Name);
        Assert.Equal("my_app", Assert.Single(db.SearchApps("_")).Name);
    }

    [Fact]
    public void Rescan_keeps_usage_and_prunes_removed_shortcuts()
    {
        var db = new DatabaseService(_tmp.Path);
        db.BulkInsertApps([App("Keep", @"C:\a\k.lnk"), App("Gone", @"C:\a\g.lnk")]);
        db.IncrementUsage(@"C:\a\k.lnk");

        db.BulkInsertApps([App("Keep", @"C:\a\k.lnk"), App("New", @"C:\a\n.lnk")]);
        var all = db.GetTopApps(10);
        Assert.Equal(["Keep", "New"], all.Select(a => a.Name));
        Assert.Equal(1, all[0].UsageCount);

        // Boş tarama (ör. Başlat Menüsü okunamadı) listeyi silmez.
        db.BulkInsertApps([]);
        Assert.Equal(2, db.GetTopApps(10).Count);

        db.RemoveApp(@"C:\a\n.lnk");
        Assert.Equal("Keep", Assert.Single(db.GetTopApps(10)).Name);
    }

    [Fact]
    public void Data_persists_across_instances()
    {
        new DatabaseService(_tmp.Path).BulkInsertApps([App("Calc", @"C:\a\c.lnk")]);
        Assert.Single(new DatabaseService(_tmp.Path).SearchApps("calc"));
        Assert.True(File.Exists(_tmp.Combine("launcher.db")));
    }

    [Fact]
    public void Legacy_db_is_copied_once_and_never_overwritten()
    {
        var legacy = Directory.CreateDirectory(_tmp.Combine("legacy")).FullName;
        var target = _tmp.Combine("new");
        File.WriteAllText(System.IO.Path.Combine(legacy, "launcher.db"), "eski");

        DatabaseService.MigrateLegacyData(legacy, target);
        Assert.Equal("eski", File.ReadAllText(System.IO.Path.Combine(target, "launcher.db")));

        File.WriteAllText(System.IO.Path.Combine(target, "launcher.db"), "yeni");
        DatabaseService.MigrateLegacyData(legacy, target);
        Assert.Equal("yeni", File.ReadAllText(System.IO.Path.Combine(target, "launcher.db")));
    }

    [Fact]
    public void Data_folder_honours_env_override()
    {
        var old = Environment.GetEnvironmentVariable(DatabaseService.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, _tmp.Path);
            Assert.Equal(_tmp.Path, DatabaseService.ResolveDataFolder());
            Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, null);
            Assert.EndsWith("KomutPaleti", DatabaseService.ResolveDataFolder());
        }
        finally { Environment.SetEnvironmentVariable(DatabaseService.DataDirEnvVar, old); }
    }
}

public class LaunchHelperTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void Existing_file_and_folder_paths_resolve()
    {
        var file = _tmp.Combine("not.txt");
        File.WriteAllText(file, "x");

        Assert.Equal(file, MainViewModel.TryResolvePath(file));
        Assert.Equal(file, MainViewModel.TryResolvePath($"  \"{file}\" "));
        Assert.Equal(_tmp.Path, MainViewModel.TryResolvePath(_tmp.Path));
        Assert.Equal(Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            MainViewModel.TryResolvePath("%SystemRoot%"), ignoreCase: true);
    }

    [Theory]
    [InlineData("notepad")]
    [InlineData("C:")]
    [InlineData(@"relative\path")]
    [InlineData(@"\\sunucu\paylasim")]
    [InlineData(@"C:\kesinlikle\olmayan\klasor")]
    public void Non_paths_do_not_resolve(string query) => Assert.Null(MainViewModel.TryResolvePath(query));

    [Fact]
    public void PowerShell_arguments_keep_window_open_and_escape_quotes()
    {
        Assert.Equal("-NoExit -NoProfile -Command \"echo \\\"merhaba\\\"\"", MainViewModel.BuildPowerShellArguments("echo \"merhaba\""));
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir_and_stays_running()
    {
        // Kullanıcının açık bir örneği varsa (tek örnek + Alt+Space çakışması) atla.
        if (Process.GetProcessesByName("KomutPaleti").Length > 0)
            return;

        var exe = System.IO.Path.Combine(AppContext.BaseDirectory, "KomutPaleti.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment[DatabaseService.DataDirEnvVar] = _tmp.Path;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandi");
            Assert.True(File.Exists(_tmp.Combine("launcher.db")), "Veri klasoru gecersiz kilinamadi");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}
