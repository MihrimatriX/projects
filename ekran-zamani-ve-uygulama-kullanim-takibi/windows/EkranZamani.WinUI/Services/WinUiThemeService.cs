using Microsoft.UI.Xaml;

namespace EkranZamani_WinUI.Services;

public static class WinUiThemeService
{
    public static void Apply(string themeId)
    {
        if (Application.Current == null) return;

        var theme = themeId switch
        {
            "dark" => ApplicationTheme.Dark,
            "light" => ApplicationTheme.Light,
            _ => ApplicationTheme.Light
        };

        try
        {
            Application.Current.RequestedTheme = theme;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Theme apply: {ex.Message}");
        }
    }
}
