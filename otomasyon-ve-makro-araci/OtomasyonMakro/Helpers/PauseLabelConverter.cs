using System;
using System.Globalization;
using System.Windows.Data;

namespace OtomasyonMakro.Helpers
{
    public class PauseLabelConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
            => value is true ? "Devam et" : "Duraklat";

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
            => throw new NotSupportedException();
    }
}
