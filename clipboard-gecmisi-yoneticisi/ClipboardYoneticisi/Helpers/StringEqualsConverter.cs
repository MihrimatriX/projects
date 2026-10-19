using System;
using System.Globalization;
using System.Windows.Data;

namespace ClipboardYoneticisi.Helpers
{
    public class StringEqualsConverter : IMultiValueConverter
    {
        public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
        {
            if (values.Length >= 2 && values[0] is string left && values[1] is string right)
                return left == right;

            return false;
        }

        public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
        {
            throw new NotSupportedException();
        }
    }
}
