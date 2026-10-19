using System.Diagnostics;
using System.Drawing;
using System.IO;
using EkranGoruntusu.Models;
using EkranGoruntusu.Services;
using EkranGoruntusu.Views;
using Xunit;

namespace EkranGoruntusu.Tests;

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ekran-test-" + Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public string Combine(params string[] parts) => System.IO.Path.Combine([Path, .. parts]);
    public void Dispose() { try { Directory.Delete(Path, true); } catch (IOException) { } }
}

public class DatabaseServiceTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    private string Png(DatabaseService db, string name)
    {
        var p = System.IO.Path.Combine(db.ScreenshotsFolder, name);
        File.WriteAllBytes(p, [1, 2, 3]);
        return p;
    }

    [Fact]
    public void Save_and_list_newest_first_with_ocr_text()
    {
        var db = new DatabaseService(_tmp.Combine("data"), _tmp.Combine("shots"));
        db.SaveScreenshot(Png(db, "a.png"), "ilk metin");
        db.SaveScreenshot(Png(db, "b.png"), "   ");

        var list = db.GetScreenshots();
        Assert.Equal(["b.png", "a.png"], list.Select(s => System.IO.Path.GetFileName(s.ImagePath)));
        Assert.Equal("", list[0].OcrText);
        Assert.Equal("ilk metin", list[1].OcrText);
    }

    [Fact]
    public void History_keeps_last_20_and_deletes_older_files()
    {
        var db = new DatabaseService(_tmp.Combine("data"), _tmp.Combine("shots"));
        var paths = Enumerable.Range(0, 23).Select(i => Png(db, $"{i:D2}.png")).ToList();
        foreach (var p in paths) db.SaveScreenshot(p, ""); // aynı saniyede: sıra Id ile belirlenir

        var kept = db.GetScreenshots();
        Assert.Equal(20, kept.Count);
        Assert.Equal("22.png", System.IO.Path.GetFileName(kept[0].ImagePath));
        Assert.All(paths.Take(3), p => Assert.False(File.Exists(p)));
        Assert.All(paths.Skip(3), p => Assert.True(File.Exists(p)));
    }

    [Fact]
    public void Delete_and_clear_remove_records_and_files()
    {
        var db = new DatabaseService(_tmp.Combine("data"), _tmp.Combine("shots"));
        var a = Png(db, "a.png");
        var b = Png(db, "b.png");
        db.SaveScreenshot(a, "");
        db.SaveScreenshot(b, "");

        var first = db.GetScreenshots().Single(s => s.ImagePath == a);
        db.DeleteScreenshot(first.Id, first.ImagePath);
        Assert.False(File.Exists(a));
        Assert.Single(db.GetScreenshots());

        db.ClearHistory();
        Assert.Empty(db.GetScreenshots());
        Assert.False(File.Exists(b));
    }

    [Fact]
    public void Database_file_is_not_locked_between_calls()
    {
        var data = _tmp.Combine("data");
        var db = new DatabaseService(data, _tmp.Combine("shots"));
        db.SaveScreenshot(Png(db, "a.png"), "");
        File.Move(System.IO.Path.Combine(data, "screenshots.db"), System.IO.Path.Combine(data, "moved.db"));
    }
}

public class SettingsServiceTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void Defaults_persist_and_reset()
    {
        var s = new SettingsService(_tmp.Path);
        Assert.Equal(_tmp.Combine("screenshots"), s.SaveFolder);
        Assert.Equal("{yyyy}-{MM}-{dd}_{HH}{mm}{ss}", s.FilenameTemplate);

        s.SaveFolder = _tmp.Combine("baska");
        s.FilenameTemplate = "ekran_{HH}{mm}";
        var reloaded = new SettingsService(_tmp.Path);
        Assert.Equal(_tmp.Combine("baska"), reloaded.SaveFolder);
        Assert.Equal("ekran_{HH}{mm}", reloaded.FilenameTemplate);

        reloaded.Reset();
        Assert.Equal(_tmp.Combine("screenshots"), new SettingsService(_tmp.Path).SaveFolder);
    }

    [Fact]
    public void Corrupt_settings_fall_back_to_defaults()
    {
        File.WriteAllText(_tmp.Combine("settings.json"), "{ bozuk");
        Assert.Equal(_tmp.Combine("screenshots"), new SettingsService(_tmp.Path).SaveFolder);
    }

    [Fact]
    public void FormatFilename_expands_tokens()
    {
        var s = new SettingsService(_tmp.Path);
        Assert.Equal("2026-03-07_091502.png", s.FormatFilename(new DateTime(2026, 3, 7, 9, 15, 2)));
    }

    [Theory]
    [InlineData("{yyyy}-{MM}", true)]
    [InlineData("sabit", false)]
    [InlineData("{HH}:{mm}", false)]
    [InlineData("klasor/{ss}", false)]
    [InlineData("{dd}?", false)]
    public void IsValidTemplate_requires_token_and_legal_chars(string template, bool expected) =>
        Assert.Equal(expected, SettingsService.IsValidTemplate(template));

    [Fact]
    public void Legacy_data_is_copied_once_and_never_overwrites()
    {
        var legacy = Directory.CreateDirectory(_tmp.Combine("eski")).FullName;
        var target = _tmp.Combine("yeni");
        File.WriteAllText(System.IO.Path.Combine(legacy, "screenshots.db"), "eski-db");
        File.WriteAllText(System.IO.Path.Combine(legacy, "settings.json"), "{}");

        SettingsService.MigrateLegacyData(legacy, target);
        Assert.Equal("eski-db", File.ReadAllText(System.IO.Path.Combine(target, "screenshots.db")));
        Assert.True(File.Exists(System.IO.Path.Combine(target, "settings.json")));

        File.WriteAllText(System.IO.Path.Combine(target, "screenshots.db"), "yeni-db");
        SettingsService.MigrateLegacyData(legacy, target);
        Assert.Equal("yeni-db", File.ReadAllText(System.IO.Path.Combine(target, "screenshots.db")));
    }

    [Fact]
    public void Data_folder_honours_env_override()
    {
        var old = Environment.GetEnvironmentVariable(SettingsService.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(SettingsService.DataDirEnvVar, _tmp.Path);
            Assert.Equal(_tmp.Path, SettingsService.ResolveDataFolder());
            Environment.SetEnvironmentVariable(SettingsService.DataDirEnvVar, null);
            Assert.EndsWith("GelismisEkranGoruntusu", SettingsService.ResolveDataFolder());
        }
        finally { Environment.SetEnvironmentVariable(SettingsService.DataDirEnvVar, old); }
    }
}

public class ImageAndModelTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void Pixelate_fills_each_block_with_its_average()
    {
        using var src = new Bitmap(4, 2);
        src.SetPixel(0, 0, Color.FromArgb(0, 0, 0)); src.SetPixel(1, 0, Color.FromArgb(200, 100, 50));
        src.SetPixel(0, 1, Color.FromArgb(0, 0, 0)); src.SetPixel(1, 1, Color.FromArgb(200, 100, 50));
        for (var x = 2; x < 4; x++) for (var y = 0; y < 2; y++) src.SetPixel(x, y, Color.White);

        using var px = EditorWindow.Pixelate(src, 2);

        for (var x = 0; x < 2; x++) for (var y = 0; y < 2; y++)
            Assert.Equal(Color.FromArgb(255, 100, 50, 25).ToArgb(), px.GetPixel(x, y).ToArgb());
        Assert.Equal(Color.White.ToArgb(), px.GetPixel(3, 1).ToArgb());
    }

    [Fact]
    public void Pixelate_handles_partial_edge_blocks()
    {
        using var src = new Bitmap(5, 3);
        using (var g = Graphics.FromImage(src)) g.Clear(Color.Red);
        using var px = EditorWindow.Pixelate(src, 4);
        Assert.Equal(Color.Red.ToArgb(), px.GetPixel(4, 2).ToArgb());
    }

    [Fact]
    public void ScreenshotItem_preview_text_and_missing_file()
    {
        var item = new ScreenshotItem(1, _tmp.Combine("yok.png"), new string('a', 100), DateTime.Now);
        Assert.Equal(78, item.OcrPreviewText.Length);
        Assert.EndsWith("…", item.OcrPreviewText);
        Assert.Null(item.Thumbnail);
        Assert.Null(item.Preview);
        Assert.Equal("Metin çözümlenmedi.", new ScreenshotItem(2, "x", " ", DateTime.Now).OcrPreviewText);
    }

    [Fact]
    public void ScreenshotItem_loads_full_resolution_preview()
    {
        var path = _tmp.Combine("b.png");
        using (var bmp = new Bitmap(400, 100)) bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        var item = new ScreenshotItem(1, path, "", DateTime.Now);
        Assert.Equal(160, ((System.Windows.Media.Imaging.BitmapSource)item.Thumbnail!).PixelWidth);
        Assert.Equal(400, ((System.Windows.Media.Imaging.BitmapSource)item.Preview!).PixelWidth);
    }
}

public class StartupSmokeTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void App_starts_with_temp_data_dir_and_stays_running()
    {
        // Kullanıcının açık bir örneği varsa (kısayol çakışması) atla.
        if (Process.GetProcessesByName("EkranGoruntusu").Length > 0)
            return;

        var exe = System.IO.Path.Combine(AppContext.BaseDirectory, "EkranGoruntusu.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment[SettingsService.DataDirEnvVar] = _tmp.Path;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandi");
            Assert.True(File.Exists(_tmp.Combine("screenshots.db")), "Veri klasoru gecersiz kilinamadi");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}
