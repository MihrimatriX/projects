using SistemYoneticisi.Helpers;
using SistemYoneticisi.Modules;
using SistemYoneticisi.Services;
using SistemYoneticisi.ViewModels;
using Xunit;

namespace SistemYoneticisi.Tests;

public class HotkeyParserTests
{
    [Theory]
    [InlineData("Ctrl+Shift+M", true)]
    [InlineData("Alt+F4", true)]
    [InlineData("Invalid", false)]
    public void TryParse_validates_hotkey_strings(string hotkey, bool expected)
    {
        var ok = HotkeyParser.TryParse(hotkey, out var key, out var mods);
        Assert.Equal(expected, ok);
        if (expected)
        {
            Assert.NotEqual(System.Windows.Input.Key.None, key);
            Assert.NotEqual(System.Windows.Input.ModifierKeys.None, mods);
        }
    }
}

[Collection("SettingsTests")]
public class SettingsImportExportTests
{
    [Fact]
    public void Export_and_import_roundtrip_preserves_values()
    {
        var path = Path.Combine(Path.GetTempPath(), $"syp-settings-{Guid.NewGuid():N}.json");
        var original = new AppSettings
        {
            HistoryEnabled = true,
            CpuAlarmThreshold = 88,
            ShowHotkey = "Ctrl+Shift+M",
            WelcomeShown = true
        };

        SettingsService.Instance.Settings = original;
        SettingsService.Instance.ExportTo(path);

        SettingsService.Instance.Settings = new AppSettings();
        SettingsService.Instance.Settings.WelcomeShown = true;
        Assert.True(SettingsService.Instance.TryImportFrom(path));

        var imported = SettingsService.Instance.Settings;
        Assert.True(imported.HistoryEnabled);
        Assert.Equal(88, imported.CpuAlarmThreshold);
        Assert.Equal("Ctrl+Shift+M", imported.ShowHotkey);
        Assert.True(imported.WelcomeShown);

        File.Delete(path);
    }
}

public class ModuleNavItemTests
{
    [Fact]
    public void NavLabel_matches_module_title()
    {
        var registry = new ModuleRegistry();
        BuiltInModules.RegisterAll(registry);
        var dashboard = registry.Modules.First(m => m.Id == "Dashboard");

        var item = new ModuleNavItem(dashboard);
        Assert.Equal("Dashboard", item.NavLabel);
        Assert.Equal("Dashboard", item.Id);
    }
}
