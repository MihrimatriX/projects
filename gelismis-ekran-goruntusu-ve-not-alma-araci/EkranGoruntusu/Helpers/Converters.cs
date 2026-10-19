using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace EkranGoruntusu.Helpers;

public sealed class NullToVisibilityConverter : IValueConverter
{
    // Değer varken görünür; "Inverse" ile değer yokken (null ya da boş metin) görünür.
    // Önceden tersti: seçim yapılınca detay paneli gizleniyor, yer tutucu görünüyordu.
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var visible = value is not (null or "");
        if (parameter?.ToString() == "Inverse")
            visible = !visible;
        return visible ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var visible = value is true;
        if (parameter?.ToString() == "Inverse")
            visible = !visible;
        return visible ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
