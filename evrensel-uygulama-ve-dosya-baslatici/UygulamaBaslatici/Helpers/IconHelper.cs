using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace UygulamaBaslatici.Helpers
{
    public static class IconHelper
    {
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool DestroyIcon(IntPtr hIcon);

        public static ImageSource? ExtractIconToImageSource(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    using (var icon = Icon.ExtractAssociatedIcon(path))
                    {
                        if (icon != null)
                        {
                            var hIcon = icon.Handle;
                            var source = Imaging.CreateBitmapSourceFromHIcon(
                                hIcon,
                                Int32Rect.Empty,
                                BitmapSizeOptions.FromEmptyOptions());

                            // HICON'u Icon nesnesi sahiplenir; using/Dispose zaten DestroyIcon çağırır (elle çağırmak çift serbest bırakma olur).
                            source.Freeze(); // Cross-thread safety
                            return source;
                        }
                    }
                }
            }
            catch
            {
                // Return null if fails, letting fallback emojis handle it
            }
            return null;
        }
    }
}
