using System.Windows;
using System.Windows.Media;

namespace SistemYoneticisi.Services;

public static class ThemeService
{
    private static readonly (string Key, Color Normal, Color HighContrast)[] Tokens =
    [
        ("BgAppColor", Color.FromRgb(0x0C, 0x0E, 0x12), Colors.Black),
        ("BgSidebarColor", Color.FromRgb(0x0A, 0x0C, 0x10), Color.FromRgb(20, 20, 20)),
        ("CardColor", Color.FromRgb(0x15, 0x19, 0x21), Color.FromRgb(40, 40, 40)),
        ("TableColor", Color.FromRgb(0x11, 0x14, 0x1A), Color.FromRgb(30, 30, 30)),
        ("HoverColor", Color.FromRgb(0x1C, 0x21, 0x29), Color.FromRgb(50, 50, 50)),
        ("AccentNavColor", Color.FromRgb(0x63, 0x66, 0xF1), Color.FromRgb(0, 200, 120)),
        ("AccentHoverColor", Color.FromRgb(0x55, 0x58, 0xE8), Color.FromRgb(0, 220, 140)),
        ("AccentCpuColor", Color.FromRgb(0x3B, 0x82, 0xF6), Color.FromRgb(100, 180, 255)),
        ("AccentRamColor", Color.FromRgb(0x8B, 0x5C, 0xF6), Color.FromRgb(180, 140, 255)),
        ("AccentDiskColor", Color.FromRgb(0xF5, 0x9E, 0x0B), Color.FromRgb(255, 200, 80)),
        ("AccentNetColor", Color.FromRgb(0x22, 0xC5, 0x5E), Color.FromRgb(80, 220, 120)),
        ("TextColor", Color.FromRgb(0xF3, 0xF4, 0xF6), Colors.White),
        ("SubTextColor", Color.FromRgb(0x9C, 0xA3, 0xAF), Color.FromRgb(200, 200, 200)),
        ("MutedTextColor", Color.FromRgb(0x6B, 0x72, 0x80), Color.FromRgb(160, 160, 160)),
        ("BorderColor", Color.FromRgb(0x25, 0x2A, 0x35), Color.FromRgb(120, 120, 120)),
        ("DangerColor", Color.FromRgb(0xEF, 0x44, 0x44), Color.FromRgb(255, 100, 100)),
        ("SuccessColor", Color.FromRgb(0x22, 0xC5, 0x5E), Color.FromRgb(80, 220, 120)),
        ("WarningColor", Color.FromRgb(0xF5, 0x9E, 0x0B), Color.FromRgb(255, 200, 80)),
    ];

    public static void ApplyHighContrast(bool enabled)
    {
        var app = Application.Current;
        if (app == null) return;

        foreach (var (key, normal, highContrast) in Tokens)
            app.Resources[key] = enabled ? highContrast : normal;

        RefreshBrushes(app);
    }

    private static void RefreshBrushes(Application app)
    {
        app.Resources["PrimaryBrush"] = Brush("BgAppColor");
        app.Resources["SidebarBrush"] = Brush("BgSidebarColor");
        app.Resources["SecondaryBrush"] = Brush("BgSidebarColor");
        app.Resources["CardBrush"] = Brush("CardColor");
        app.Resources["TableBrush"] = Brush("TableColor");
        app.Resources["HoverBrush"] = Brush("HoverColor");
        app.Resources["AccentBrush"] = Brush("AccentNavColor");
        app.Resources["HighlightBrush"] = Brush("AccentHoverColor");
        app.Resources["AccentCpuBrush"] = Brush("AccentCpuColor");
        app.Resources["AccentRamBrush"] = Brush("AccentRamColor");
        app.Resources["AccentDiskBrush"] = Brush("AccentDiskColor");
        app.Resources["AccentNetBrush"] = Brush("AccentNetColor");
        app.Resources["TextBrush"] = Brush("TextColor");
        app.Resources["SubTextBrush"] = Brush("SubTextColor");
        app.Resources["MutedTextBrush"] = Brush("MutedTextColor");
        app.Resources["BorderBrush"] = Brush("BorderColor");
        app.Resources["DangerBrush"] = Brush("DangerColor");
        app.Resources["SuccessBrush"] = Brush("SuccessColor");
        app.Resources["WarningBrush"] = Brush("WarningColor");
    }

    private static SolidColorBrush Brush(string colorKey) =>
        new((Color)Application.Current!.Resources[colorKey]);
}
