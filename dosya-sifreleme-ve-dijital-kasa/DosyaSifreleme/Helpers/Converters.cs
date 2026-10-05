using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace DosyaSifreleme.Helpers;

public class BoolToTextConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is bool val && parameter is string paramStr)
        {
            var parts = paramStr.Split('|');
            if (parts.Length >= 2)
                return val ? parts[0] : parts[1];
        }
        return string.Empty;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        bool inverse = parameter is string s && s.Equals("Inverse", StringComparison.OrdinalIgnoreCase);
        bool empty = value switch
        {
            null => true,
            string str => string.IsNullOrWhiteSpace(str),
            int n => n == 0,
            _ => false
        };
        return empty
            ? (inverse ? Visibility.Visible : Visibility.Collapsed)
            : (inverse ? Visibility.Collapsed : Visibility.Visible);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class NullToBoolConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not (null or 0); // 0 = bos liste

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class InverseBoolConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is bool b && !b;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is bool b && !b;
}

public class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        bool inverse = parameter is string s && s.Equals("Inverse", StringComparison.OrdinalIgnoreCase);
        bool visible = value is bool b && b;
        if (inverse) visible = !visible;
        return visible ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class StrengthSegmentBrushConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        int score = value is int s ? s : 0;
        int index = int.TryParse(parameter?.ToString(), out var i) ? i : 0;
        if (index >= score)
            return Application.Current.FindResource("BorderBrush");

        return score switch
        {
            1 => Application.Current.FindResource("WarningBrush"),
            2 => Application.Current.FindResource("AccentBrush"),
            _ => Application.Current.FindResource("AccentSecureBrush")
        };
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class StrengthLabelBrushConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        int score = value is int s ? s : 0;
        return score switch
        {
            0 => Application.Current.FindResource("MutedBrush"),
            1 => Application.Current.FindResource("WarningBrush"),
            2 => Application.Current.FindResource("AccentBrush"),
            _ => Application.Current.FindResource("AccentSecureBrush")
        };
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
