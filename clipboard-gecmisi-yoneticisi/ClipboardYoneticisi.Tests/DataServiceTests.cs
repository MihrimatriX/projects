using System.IO;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Text.Json;
using ClipboardYoneticisi.Services;
using Xunit;

namespace ClipboardYoneticisi.Tests;

internal static class TestEnvironment
{
    public static readonly string DataDir = Path.Combine(Path.GetTempPath(), "cgy-tests-" + Guid.NewGuid().ToString("N"));

    // Tum test sureci gercek %LocalAppData% verisi yerine gecici klasoru kullanir.
    [ModuleInitializer]
    internal static void Init()
    {
        Environment.SetEnvironmentVariable("CLIPBOARD_GECMISI_DATA_DIR", DataDir);
        AppDomain.CurrentDomain.ProcessExit += (_, _) => DeleteQuietly(DataDir);
    }

    public static void DeleteQuietly(string dir)
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        try { Directory.Delete(dir, recursive: true); } catch { /* en iyi caba */ }
    }
}

public class DataServiceTests
{
    private readonly DatabaseService _db = new();

    private static string Unique(string prefix) => $"{prefix} {Guid.NewGuid():N}";

    private ClipboardItemData Find(string content) => _db.GetItems().Single(i => i.Content == content);

    [Fact]
    public void Data_is_isolated_in_temp_folder()
    {
        Assert.StartsWith(TestEnvironment.DataDir, AppPaths.DbPath);
    }

    [Fact]
    public void SaveItem_dedupes_and_pin_delete_work()
    {
        var text = Unique("not");
        Assert.True(_db.SaveItem("Text", text));
        Assert.True(_db.SaveItem("Text", text));
        var item = Find(text);

        _db.TogglePin(item.Id, true);
        Assert.True(Find(text).IsPinned);

        _db.DeleteItem(item.Id, item.Type, item.Content);
        Assert.DoesNotContain(_db.GetItems(), i => i.Content == text);
    }

    [Fact]
    public void SaveItem_blocks_regex_filtered_content()
    {
        Assert.False(_db.SaveItem("Text", "1234567812345678"));
    }

    [Fact]
    public void Search_finds_text_and_ignores_others()
    {
        var token = "zebra" + Guid.NewGuid().ToString("N")[..6];
        _db.SaveItem("Text", $"merhaba {token} dunya");
        _db.SaveItem("Text", Unique("alakasiz"));

        var hits = _db.GetItems(token);
        Assert.Single(hits);
        Assert.Contains(token, hits[0].Content);
    }

    [Fact]
    public void ClearHistory_keeps_pinned_items()
    {
        var keep = Unique("sabit");
        var drop = Unique("gecici");
        _db.SaveItem("Text", keep, isPinned: true);
        _db.SaveItem("Text", drop);

        _db.ClearHistory();

        var items = _db.GetItems();
        Assert.Contains(items, i => i.Content == keep);
        Assert.DoesNotContain(items, i => i.Content == drop);
    }

    [Fact]
    public async Task Export_import_roundtrip_keeps_pin_time_and_images()
    {
        var service = new ExportImportService(_db);
        var pinned = Unique("yedek-sabit");
        var old = new DateTime(2024, 1, 2, 3, 4, 5);
        _db.SaveItem("Text", pinned, timestamp: old, isPinned: true);

        var imgPath = Path.Combine(_db.ImageFolder, Guid.NewGuid() + ".png");
        byte[] png = [137, 80, 78, 71, 1, 2, 3];
        File.WriteAllBytes(imgPath, png);
        _db.SaveItem("Image", imgPath);

        var backup = Path.Combine(TestEnvironment.DataDir, Guid.NewGuid() + ".json");
        var exported = await service.ExportToFileAsync(backup);
        Assert.True(exported >= 2);

        // Temizle + ice aktar: sabitleme kaldirilip temizlense bile yedekten geri gelmeli
        _db.TogglePin(Find(pinned).Id, false);
        var imported = await service.ImportFromFileAsync(backup, merge: false);
        Assert.Equal(exported, imported);

        var restored = Find(pinned);
        Assert.True(restored.IsPinned);
        Assert.Equal(old, restored.Timestamp);

        var image = _db.GetItems().First(i => i.Type == "Image" && File.Exists(i.Content) && File.ReadAllBytes(i.Content).SequenceEqual(png));
        Assert.NotNull(image);
    }

    [Fact]
    public async Task Import_rejects_invalid_file()
    {
        var bad = Path.Combine(TestEnvironment.DataDir, Guid.NewGuid() + ".json");
        File.WriteAllText(bad, "bu json degil");
        await Assert.ThrowsAsync<InvalidDataException>(() => new ExportImportService(_db).ImportFromFileAsync(bad, merge: true));
    }
}

public class StartupSmokeTests
{
    [Fact]
    public void App_starts_and_stays_running()
    {
        // Kullanicinin calisan ornegi varsa tek-ornek kilidi nedeniyle test anlamsiz; atla.
        if (Process.GetProcessesByName("ClipboardGecmisiYoneticisi").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "ClipboardGecmisiYoneticisi.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var dataDir = Path.Combine(Path.GetTempPath(), "cgy-smoke-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dataDir);
        // Hosgeldin/guncelleme kapali; baslangic ayari mevcut kayit defteri durumuyla ayni (degistirilmesin).
        File.WriteAllText(Path.Combine(dataDir, "settings.json"), JsonSerializer.Serialize(new AppSettings
        {
            FirstRunCompleted = true,
            CheckForUpdates = false,
            StartWithWindows = StartupService.IsEnabled()
        }));

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment["CLIPBOARD_GECMISI_DATA_DIR"] = dataDir;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), $"Uygulama erken kapandi (kod {(proc.HasExited ? proc.ExitCode : 0)})");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
        Assert.True(File.Exists(Path.Combine(dataDir, "clipboard.db")));
        TestEnvironment.DeleteQuietly(dataDir);
    }
}
