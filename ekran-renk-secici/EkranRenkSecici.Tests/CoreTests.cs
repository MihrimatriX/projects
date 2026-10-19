using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows.Input;
using System.Windows.Media;
using EkranRenkSecici.Helpers;
using EkranRenkSecici.Models;
using EkranRenkSecici.Services;
using Xunit;
using Color = System.Windows.Media.Color;

namespace EkranRenkSecici.Tests;

public class ColorHelperTests
{
    private static readonly Color Blue = Color.FromRgb(0x3B, 0x82, 0xF6);

    [Fact]
    public void Formats_hex_rgb_hsl()
    {
        Assert.Equal("#3B82F6", ColorHelper.ToHex(Blue));
        Assert.Equal("rgb(59, 130, 246)", ColorHelper.ToRgbString(Blue));
        Assert.Equal("hsl(217, 91%, 60%)", ColorHelper.ToHslString(Blue));
    }

    [Fact]
    public void Hsl_roundtrip_keeps_color()
    {
        var (h, s, l) = ColorHelper.ToHsl(Blue);
        Assert.Equal(Blue, ColorHelper.FromHsl(h, s, l));
    }

    [Fact]
    public void Complementary_of_red_is_cyan()
    {
        Assert.Equal(Color.FromRgb(0, 255, 255), ColorHelper.GetComplementary(Color.FromRgb(255, 0, 0)));
    }

    [Fact]
    public void Css_and_json_outputs_are_culture_invariant()
    {
        var old = CultureInfo.CurrentCulture;
        CultureInfo.CurrentCulture = new CultureInfo("tr-TR");
        try
        {
            Assert.Equal("oklch(62.3% 0.188 259.8)", ColorHelper.ToOklchString(Blue));
            // tr-TR'de ondalik virgul Figma JSON'unu bozuyordu
            using var doc = JsonDocument.Parse(ColorHelper.ExportFigma(Blue));
            Assert.Equal(3, doc.RootElement.GetProperty("picked").GetProperty("$value").GetProperty("components").GetArrayLength());
            Assert.Contains("--color-picked-oklch: oklch(62.3%", ColorHelper.ExportCssVariables(Blue));
        }
        finally
        {
            CultureInfo.CurrentCulture = old;
        }
    }

    [Fact]
    public void Contrast_and_wcag_levels()
    {
        var ratio = ColorHelper.GetContrastRatio(Colors.Black, Colors.White);
        Assert.Equal(21.0, ratio, 2);
        Assert.Equal("AAA ✓", ColorHelper.GetWcagNormalTextStatus(ratio));
        Assert.Equal("AA ✗", ColorHelper.GetWcagNormalTextStatus(3.5));
        Assert.Equal("AA ✓", ColorHelper.GetWcagLargeTextStatus(3.5));
        Assert.Equal(1.0, ColorHelper.GetContrastRatio(Blue, Blue), 3);
    }

    [Fact]
    public void Color_blindness_simulation()
    {
        Assert.Equal(Blue, ColorHelper.SimulateColorBlindness(Blue, ColorHelper.ColorBlindnessType.None));
        Assert.NotEqual(Blue, ColorHelper.SimulateColorBlindness(Blue, ColorHelper.ColorBlindnessType.Protan));
        var gray = Color.FromRgb(128, 128, 128);
        Assert.Equal(gray, ColorHelper.SimulateColorBlindness(gray, ColorHelper.ColorBlindnessType.Deutan));
    }

    [Theory]
    [InlineData("#3B82F6")]
    [InlineData("3b82f6")]
    [InlineData("  #3B82F6  ")]
    [InlineData("rgb(59, 130, 246)")]
    [InlineData("RGB(59 130 246)")]
    public void TryParse_accepts_common_formats(string input)
    {
        Assert.True(ColorHelper.TryParse(input, out var c));
        Assert.Equal(Blue, c);
    }

    [Fact]
    public void TryParse_expands_short_hex()
    {
        Assert.True(ColorHelper.TryParse("#38F", out var c));
        Assert.Equal(Color.FromRgb(0x33, 0x88, 0xFF), c);
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("#12345")]
    [InlineData("#GGGGGG")]
    [InlineData("rgb(300, 0, 0)")]
    [InlineData("mavi")]
    public void TryParse_rejects_invalid(string? input)
    {
        Assert.False(ColorHelper.TryParse(input, out _));
    }

    [Fact]
    public void FormatForCopy_and_tailwind_export()
    {
        Assert.Equal("--color-picked: #3B82F6;", ColorHelper.FormatForCopy(Blue, CopyFormat.CSS));
        Assert.Contains("picked: '#3B82F6'", ColorHelper.ExportTailwind(Blue));
        Assert.Equal(5, ColorHelper.GetExportPalette(Blue).Count);
    }

    [Fact]
    public void Average_color_samples_neighbourhood()
    {
        using var bmp = new System.Drawing.Bitmap(3, 3);
        for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            bmp.SetPixel(x, y, x == 1 && y == 1 ? System.Drawing.Color.White : System.Drawing.Color.Black);

        Assert.Equal(Colors.White, ColorHelper.GetAverageColor(bmp, 1, 1, 1));
        Assert.Equal(Color.FromRgb(28, 28, 28), ColorHelper.GetAverageColor(bmp, 1, 1, 3)); // 255/9
        Assert.Equal(Colors.Black, ColorHelper.GetAverageColor(bmp, 0, 0, 1));
    }
}

public class HotkeyHelperTests
{
    [Fact]
    public void Parses_and_formats_hotkeys()
    {
        Assert.Equal(ModifierKeys.Control | ModifierKeys.Shift, HotkeyHelper.ParseModifiers("Control, Shift"));
        Assert.Equal(ModifierKeys.Control, HotkeyHelper.ParseModifiers("")); // bos -> Ctrl
        Assert.Equal(Key.X, HotkeyHelper.ParseKey("x"));
        Assert.Equal(Key.C, HotkeyHelper.ParseKey("gecersiz"));
        Assert.Equal("Ctrl+Alt+P", HotkeyHelper.FormatDisplay("Control,Alt", "p"));
    }
}

public class SettingsServiceTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "ers-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); } catch { /* en iyi caba */ }
    }

    [Fact]
    public void Settings_are_saved_and_normalized()
    {
        new SettingsService(_dir).Save(new AppSettings
        {
            HotkeyKey = "X", SampleSize = 7, MagnifierZoom = 99, DefaultCopyFormat = CopyFormat.OKLCH
        });

        var reloaded = new SettingsService(_dir).Current;
        Assert.Equal("X", reloaded.HotkeyKey);
        Assert.Equal(3, reloaded.SampleSize);
        Assert.Equal(16, reloaded.MagnifierZoom);
        Assert.Equal(CopyFormat.OKLCH, reloaded.DefaultCopyFormat);
    }

    [Fact]
    public void Corrupt_settings_fall_back_to_defaults()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(Path.Combine(_dir, "settings.json"), "{bozuk");
        Assert.Equal("C", new SettingsService(_dir).Current.HotkeyKey);
    }

    [Fact]
    public void History_roundtrips_and_survives_corruption()
    {
        var svc = new SettingsService(_dir);
        Assert.Empty(svc.LoadHistory());

        svc.SaveHistory(["#3B82F6", "#FFFFFF"]);
        Assert.Equal(["#3B82F6", "#FFFFFF"], new SettingsService(_dir).LoadHistory());

        File.WriteAllText(Path.Combine(_dir, "history.json"), "not json");
        Assert.Empty(svc.LoadHistory());
    }
}

public class StartupSmokeTests
{
    [Fact]
    public void App_starts_and_stays_running()
    {
        // Kullanicinin acik bir ornegi varsa (kisayol cakismasi) atla.
        if (Process.GetProcessesByName("EkranRenkSecici").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "EkranRenkSecici.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        // Gecici veri klasoru: gercek %AppData%\EkranRenkSecici ayar/gecmisine dokunulmaz.
        var dataDir = Path.Combine(Path.GetTempPath(), "ers-smoke-" + Guid.NewGuid().ToString("N"));
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment["EKRAN_RENK_SECICI_DATA_DIR"] = dataDir;
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandi");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
            try { Directory.Delete(dataDir, recursive: true); } catch { /* en iyi caba */ }
        }
    }
}
