using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace EkranRenkSecici.Helpers;

public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        bool isInverse = parameter is string s && s.Equals("Inverse", StringComparison.OrdinalIgnoreCase);
        bool empty = value == null || (value is string str && string.IsNullOrWhiteSpace(str));
        return empty
            ? (isInverse ? Visibility.Visible : Visibility.Collapsed)
            : (isInverse ? Visibility.Collapsed : Visibility.Visible);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
