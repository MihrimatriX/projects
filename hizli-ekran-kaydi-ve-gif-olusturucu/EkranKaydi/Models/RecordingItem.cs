using System.Globalization;
using System.IO;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace EkranKaydi.Models
{
    public class RecordingItem
    {
        public int Id { get; }
        public string FilePath { get; }
        public string Type { get; } // ""GIF"" or ""MP4""
        public double DurationSeconds { get; }
        public int Width { get; }
        public int Height { get; }
        public DateTime Timestamp { get; }
        public string ThumbnailPath { get; }

        private BitmapImage? _cachedThumbnail;

        public RecordingItem(int id, string filePath, string type, double durationSeconds, int width, int height, DateTime timestamp)
        {
            Id = id;
            FilePath = filePath;
            Type = type;
            DurationSeconds = durationSeconds;
            Width = width;
            Height = height;
            Timestamp = timestamp;

            // Küçük resim veri klasöründe; klasör ffmpeg yazarken oluşturulur
            ThumbnailPath = Path.Combine(EkranKaydi.Services.AppPaths.ThumbnailsFolder, $"thumb_{Id}.png");
        }

        public string FormattedDate => Timestamp.ToString("d MMM yyyy, HH:mm", new CultureInfo("tr-TR"));

        public string FormattedDuration => $"{DurationSeconds:F1} sn";

        public string ResolutionString => $"{Width}×{Height}";

        public string FileSizeString
        {
            get
            {
                if (!File.Exists(FilePath)) return "0 KB";
                try
                {
                    long bytes = new FileInfo(FilePath).Length;
                    if (bytes >= 1024 * 1024)
                        return $"{(double)bytes / (1024 * 1024):F1} MB";
                    return $"{bytes / 1024} KB";
                }
                catch
                {
                    return "Bilinmiyor";
                }
            }
        }

        public ImageSource? Thumbnail
        {
            get
            {
                // For GIF, we can directly bind the GIF path itself or use the thumbnail.
                // If it is MP4, we use the generated thumbnail path.
                string sourcePath = FilePath;
                if (Type.Equals("MP4", StringComparison.OrdinalIgnoreCase))
                {
                    if (File.Exists(ThumbnailPath))
                    {
                        sourcePath = ThumbnailPath;
                    }
                    else
                    {
                        // Fallback if thumb is not ready yet
                        return null;
                    }
                }

                if (!File.Exists(sourcePath)) return null;

                if (_cachedThumbnail == null)
                {
                    try
                    {
                        var bitmap = new BitmapImage();
                        bitmap.BeginInit();
                        bitmap.CacheOption = BitmapCacheOption.OnLoad; // Crucial to prevent file lock
                        bitmap.UriSource = new Uri(sourcePath);
                        bitmap.DecodePixelWidth = 150; // Performance optimization for lists
                        bitmap.EndInit();
                        bitmap.Freeze();
                        _cachedThumbnail = bitmap;
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Failed to load thumbnail image: {ex.Message}");
                        return null;
                    }
                }
                return _cachedThumbnail;
            }
        }
    }
}
