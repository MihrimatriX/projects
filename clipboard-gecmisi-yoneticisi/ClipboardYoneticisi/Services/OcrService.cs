using System;
using System.IO;
using System.Threading.Tasks;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using Windows.Storage.Streams;

namespace ClipboardYoneticisi.Services
{
    public class OcrService
    {
        private static OcrService? _instance;
        public static OcrService Instance => _instance ??= new OcrService();

        public async Task<string?> ExtractTextAsync(string imagePath)
        {
            if (!SettingsService.Instance.Settings.EnableOcr || !File.Exists(imagePath))
                return null;

            try
            {
                var file = await StorageFile.GetFileFromPathAsync(imagePath);
                using IRandomAccessStream stream = await file.OpenAsync(FileAccessMode.Read);
                var decoder = await BitmapDecoder.CreateAsync(stream);
                using var softwareBitmap = await decoder.GetSoftwareBitmapAsync(
                    BitmapPixelFormat.Bgra8,
                    BitmapAlphaMode.Premultiplied);

                var engine = OcrEngine.TryCreateFromUserProfileLanguages();
                if (engine == null)
                    return null;

                var result = await engine.RecognizeAsync(softwareBitmap);
                var text = result?.Text?.Trim();
                return string.IsNullOrWhiteSpace(text) ? null : text;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"OCR failed: {ex.Message}");
                return null;
            }
        }
    }
}
