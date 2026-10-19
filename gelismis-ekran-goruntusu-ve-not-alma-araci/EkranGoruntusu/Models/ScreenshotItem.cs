using System.Globalization;
using System.IO;

namespace EkranGoruntusu.Models;

public sealed class ScreenshotItem
{
    private static readonly CultureInfo Tr = CultureInfo.GetCultureInfo("tr-TR");
    private System.Windows.Media.Imaging.BitmapImage? _cachedThumbnail;
    private System.Windows.Media.Imaging.BitmapImage? _cachedPreview;

    public ScreenshotItem(int id, string imagePath, string ocrText, DateTime timestamp)
    {
        Id = id;
        ImagePath = imagePath;
        OcrText = ocrText;
        Timestamp = timestamp;
    }

    public int Id { get; }
    public string ImagePath { get; }
    public string OcrText { get; }
    public DateTime Timestamp { get; }

    // UIA/ekran okuyucu: liste öğesinin adı tarih + dosya adıdır.
    public override string ToString() => $"{FormattedDate} · {Path.GetFileName(ImagePath)}";

    public string FormattedDate => Timestamp.ToString("d MMMM yyyy, HH:mm", Tr);

    public bool HasOcrText => !string.IsNullOrWhiteSpace(OcrText);

    public string OcrPreviewText => HasOcrText
        ? (OcrText.Length > 80 ? OcrText[..77] + "…" : OcrText)
        : "Metin çözümlenmedi.";

    // Galeri küçük resmi (160 px genişlik).
    public System.Windows.Media.ImageSource? Thumbnail =>
        File.Exists(ImagePath) ? _cachedThumbnail ??= LoadBitmap(160) : null;

    // Detay önizlemesi tam çözünürlükte (küçük resim büyütülünce bulanıklaşıyordu).
    // ponytail: yalnızca seçilen kayıtlar için yüklenir; geçmiş 20 kayıtla sınırlı olduğu için bellek sınırı yok.
    public System.Windows.Media.ImageSource? Preview =>
        File.Exists(ImagePath) ? _cachedPreview ??= LoadBitmap(null) : null;

    private System.Windows.Media.Imaging.BitmapImage? LoadBitmap(int? decodeWidth)
    {
        try
        {
            var bitmap = new System.Windows.Media.Imaging.BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(ImagePath);
            if (decodeWidth is int w) bitmap.DecodePixelWidth = w;
            bitmap.EndInit();
            bitmap.Freeze();
            return bitmap;
        }
        catch
        {
            return null;
        }
    }
}
