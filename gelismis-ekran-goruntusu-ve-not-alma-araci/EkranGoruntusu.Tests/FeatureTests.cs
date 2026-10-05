using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Input;
using EkranGoruntusu.Services;
using Xunit;

namespace EkranGoruntusu.Tests;

/// <summary>Test görseli: beyaz zemin üzerine büyük siyah metin (OCR için).</summary>
internal static class TestImage
{
    public static void WriteText(string path, string text, ImageFormat? format = null)
    {
        using var bmp = new Bitmap(900, 220, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.White);
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            using var font = new Font("Arial", 56, FontStyle.Bold, GraphicsUnit.Pixel);
            g.DrawString(text, font, Brushes.Black, 30, 70);
        }
        bmp.Save(path, format ?? ImageFormat.Png);
    }
}

public class FeatureTests : IDisposable
{
    private readonly TempDir _tmp = new();
    public void Dispose() => _tmp.Dispose();

    [Fact]
    public void All_hotkey_choices_parse()
    {
        foreach (var h in SettingsService.HotkeyChoices)
            Assert.True(SettingsService.TryParseHotkey(h, out _, out _), h);

        Assert.True(SettingsService.TryParseHotkey("Ctrl+Shift+S", out var key, out var mods));
        Assert.Equal(Key.S, key);
        Assert.Equal(ModifierKeys.Control | ModifierKeys.Shift, mods);
        Assert.True(SettingsService.TryParseHotkey("PrintScreen", out key, out mods));
        Assert.Equal((Key.PrintScreen, ModifierKeys.None), (key, mods));
        Assert.False(SettingsService.TryParseHotkey("Ctrl+Alt", out _, out _));
        Assert.False(SettingsService.TryParseHotkey("Ctrl+A+B", out _, out _));
        Assert.Equal("Ctrl + Alt + A", SettingsService.DisplayHotkey("Ctrl+Alt+A"));
    }

    [Fact]
    public void Hotkey_and_history_limit_persist_and_reject_unknown_values()
    {
        var s = new SettingsService(_tmp.Path);
        Assert.Equal(SettingsService.DefaultHotkey, s.Hotkey);
        Assert.Equal(20, s.HistoryLimit);
        s.Hotkey = "Ctrl+Shift+S";
        s.HistoryLimit = 100;
        var r = new SettingsService(_tmp.Path);
        Assert.Equal(("Ctrl+Shift+S", 100), (r.Hotkey, r.HistoryLimit));

        File.WriteAllText(_tmp.Combine("settings.json"),
            $$"""{"SaveFolder": "{{_tmp.Combine("x").Replace("\\", "\\\\")}}", "Hotkey": "Win+Q", "HistoryLimit": 7}""");
        var bad = new SettingsService(_tmp.Path);
        Assert.Equal((SettingsService.DefaultHotkey, 20), (bad.Hotkey, bad.HistoryLimit));
        Assert.Equal(_tmp.Combine("x"), bad.SaveFolder);
    }

    [Fact]
    public void History_limit_is_configurable()
    {
        var db = new DatabaseService(_tmp.Combine("data"), _tmp.Combine("shots"));
        var paths = Enumerable.Range(0, 5).Select(i => System.IO.Path.Combine(db.ScreenshotsFolder, $"{i}.png")).ToList();
        foreach (var p in paths)
        {
            File.WriteAllBytes(p, [1]);
            db.SaveScreenshot(p, "", historyLimit: 3);
        }
        Assert.Equal(3, db.GetScreenshots().Count);
        Assert.False(File.Exists(paths[0]));
        Assert.True(File.Exists(paths[4]));
    }

    [Fact]
    public void Image_file_loads_as_32bpp_copy_without_locking()
    {
        var jpg = _tmp.Combine("foto.jpg");
        TestImage.WriteText(jpg, "JPG", ImageFormat.Jpeg);
        using (var bmp = ImageFile.Load(jpg))
        {
            Assert.Equal(PixelFormat.Format32bppArgb, bmp.PixelFormat);
            Assert.Equal((900, 220), (bmp.Width, bmp.Height));
            File.Delete(jpg); // kilit yok: düzenleyici açıkken geçmişteki dosya silinebilir
        }
        Assert.ThrowsAny<Exception>(() => ImageFile.Load(_tmp.Combine("yok.png")));
    }

    [Fact]
    public async Task Ocr_reads_rendered_text_when_a_language_pack_exists()
    {
        if (Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages() == null)
            return; // dil paketi yoksa OCR boş döner (README: Bilinen sınırlar)
        var png = _tmp.Combine("ocr.png");
        TestImage.WriteText(png, "MERHABA 2026");
        var text = await OcrService.RecognizeTextFromBytesAsync(File.ReadAllBytes(png));
        Assert.Contains("2026", text);
        Assert.Equal(string.Empty, await OcrService.RecognizeTextFromBytesAsync([1, 2, 3])); // bozuk veri: çökmez
    }
}
