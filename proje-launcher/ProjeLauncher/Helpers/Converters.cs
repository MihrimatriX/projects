using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace ProjeLauncher.Helpers;

public sealed class HexToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        try
        {
            var c = (Color)ColorConverter.ConvertFromString(value as string ?? "#52525B")!;
            // Yer tutucu icin hafif gradyan: ayni renk, alt kosede koyulasir.
            if (parameter as string == "gradient")
            {
                var dark = Color.FromRgb((byte)(c.R * 0.55), (byte)(c.G * 0.55), (byte)(c.B * 0.55));
                var b = new LinearGradientBrush(c, dark, 45);
                b.Freeze();
                return b;
            }
            var s = new SolidColorBrush(c);
            s.Freeze();
            return s;
        }
        catch (FormatException)
        {
            return Brushes.Gray;
        }
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

/// <summary>Bos deger (null, "", false, 0) -> Collapsed; parameter "invert" ile tersi.</summary>
public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        (value is null or "" or false or 0) ^ (parameter as string == "invert") ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

/// <summary>Enum degeri == parameter -> true (RadioButton baglamasi icin, geri donus de destekli).</summary>
public sealed class EnumEqualsConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value?.ToString() == parameter as string;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is true ? Enum.Parse(targetType, (string)parameter) : Binding.DoNothing;
}
