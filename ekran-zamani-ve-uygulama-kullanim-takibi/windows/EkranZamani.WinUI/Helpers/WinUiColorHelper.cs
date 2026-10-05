using Microsoft.UI;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace EkranZamani_WinUI.Helpers;

public static class WinUiColorHelper
{
    public static Brush BrushFromHex(string hex)
    {
        hex = hex.TrimStart('#');
        if (hex.Length == 8)
        {
            // CSS #RRGGBBAA → WinUI AARRGGBB
            hex = hex.Substring(6, 2) + hex.Substring(0, 6);
        }
        else if (hex.Length == 6)
        {
            hex = "FF" + hex;
        }

        var c = Color.FromArgb(
            Convert.ToByte(hex.Substring(0, 2), 16),
            Convert.ToByte(hex.Substring(2, 2), 16),
            Convert.ToByte(hex.Substring(4, 2), 16),
            Convert.ToByte(hex.Substring(6, 2), 16));
        return new SolidColorBrush(c);
    }
}
