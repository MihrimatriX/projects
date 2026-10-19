using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace ProjeLauncher.Services;

/// <summary>PNG'yi arka planda, istenen genislikte cozer ve dondurur (UI is parcacigini bloklamaz).</summary>
public static class ImageLoader
{
    public static Task<ImageSource?> LoadAsync(string? path, int decodeWidth) =>
        path is null ? Task.FromResult<ImageSource?>(null) : Task.Run(() => Load(path, decodeWidth));

    public static ImageSource? Load(string path, int decodeWidth)
    {
        try
        {
            // Bellege oku: dosya kilitli kalmaz (diger agent'lar ekran.png'yi yeniden yazabilir).
            var bmp = new BitmapImage();
            bmp.BeginInit();
            bmp.StreamSource = new MemoryStream(File.ReadAllBytes(path));
            bmp.DecodePixelWidth = decodeWidth;
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
            bmp.EndInit();
            bmp.Freeze();
            return bmp;
        }
        catch (Exception) // IO, FileFormat, COM: hepsi ayni sonuc
        {
            return null; // bozuk/yarim dosya: yer tutucu gorunur
        }
    }
}
