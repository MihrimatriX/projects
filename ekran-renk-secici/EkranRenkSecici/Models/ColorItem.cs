using System.Windows.Media;
using EkranRenkSecici.Helpers;

namespace EkranRenkSecici.Models;

public sealed class ColorItem
{
    public Color Value { get; }
    public string Hex { get; }
    public string Rgb { get; }
    public string Hsl { get; }
    public string Oklch { get; }
    public string CssVariable { get; }
    public SolidColorBrush Brush { get; }

    public ColorItem(Color color)
    {
        Value = color;
        Hex = ColorHelper.ToHex(color);
        Rgb = ColorHelper.ToRgbString(color);
        Hsl = ColorHelper.ToHslString(color);
        Oklch = ColorHelper.ToOklchString(color);
        CssVariable = $"--color-picked: {Hex};";
        Brush = new SolidColorBrush(color);
        Brush.Freeze();
    }

    public string Format(CopyFormat fmt) => ColorHelper.FormatForCopy(Value, fmt);
}
