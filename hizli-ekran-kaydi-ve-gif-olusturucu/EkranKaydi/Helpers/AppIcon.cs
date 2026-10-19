using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace EkranKaydi.Helpers;

public static class AppIcon
{
    public static void Apply(Window window)
    {
        var path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "assets", "app.ico");
        if (!File.Exists(path)) return;
        window.Icon = BitmapFrame.Create(new Uri(path, UriKind.Absolute));
    }
}
