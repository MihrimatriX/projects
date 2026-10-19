using System.IO;
using System.Threading.Tasks;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;

namespace EkranGoruntusu.Services;

public static class OcrService
{
    public static async Task<string> RecognizeTextFromBytesAsync(byte[] imageBytes)
    {
        if (imageBytes.Length == 0) return string.Empty;

        try
        {
            return await Task.Run(async () =>
            {
                using var stream = new InMemoryRandomAccessStream();
                using (var writer = new DataWriter(stream.GetOutputStreamAt(0)))
                {
                    writer.WriteBytes(imageBytes);
                    await writer.StoreAsync();
                    await writer.FlushAsync();
                }

                var decoder = await BitmapDecoder.CreateAsync(stream);
                using var bitmap = await decoder.GetSoftwareBitmapAsync(
                    BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);

                // Windows'un yerleşik OCR'ı (Windows.Media.Ocr): internet gerekmez, kullanıcının dil paketlerini kullanır
                var engine = OcrEngine.TryCreateFromUserProfileLanguages();
                if (engine == null)
                    return string.Empty;

                var result = await engine.RecognizeAsync(bitmap);
                return result.Text;
            });
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"OCR failed: {ex.Message}");
            return string.Empty;
        }
    }
}
