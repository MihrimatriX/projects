using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace OtomasyonMakro.Helpers
{
    public class NullToVisibilityConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            bool isNull = value == null;
            if (parameter?.ToString() == "Inverse")
                return isNull ? Visibility.Visible : Visibility.Collapsed;
            return isNull ? Visibility.Collapsed : Visibility.Visible;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
            => throw new NotSupportedException();
    }

    public class BooleanToVisibilityConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            if (value is not bool b) return Visibility.Collapsed;
            if (parameter?.ToString() == "Inverse")
                return b ? Visibility.Collapsed : Visibility.Visible;
            return b ? Visibility.Visible : Visibility.Collapsed;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
            => throw new NotSupportedException();
    }

    public class InverseBooleanConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
            => value is bool b && !b;

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
            => value is bool b && !b;
    }
}
