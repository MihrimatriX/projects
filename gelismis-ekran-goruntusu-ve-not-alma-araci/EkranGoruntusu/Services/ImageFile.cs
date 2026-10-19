using System.Drawing;
using System.IO;

namespace EkranGoruntusu.Services;

public static class ImageFile
{
    /// <summary>
    /// Görseli belleğe 32 bit ARGB kopya olarak yükler: dosya kilitli kalmaz (geçmişteki PNG silinebilir) ve
    /// düzenleyici (Bgra32 dönüşümü, bulanıklaştırma) JPG/BMP gibi 24 bit biçimlerde de doğru çalışır.
    /// </summary>
    public static Bitmap Load(string path)
    {
        using var stream = new MemoryStream(File.ReadAllBytes(path));
        using var source = new Bitmap(stream);
        var copy = new Bitmap(source.Width, source.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(copy))
            g.DrawImage(source, 0, 0, source.Width, source.Height);
        return copy;
    }
}
