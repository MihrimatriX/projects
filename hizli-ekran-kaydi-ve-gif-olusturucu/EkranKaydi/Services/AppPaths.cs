using System.IO;

namespace EkranKaydi.Services;

/// <summary>
/// Yazılabilir veri konumu: %LOCALAPPDATA%\EkranKaydi (exe klasörü Program Files'ta salt okunur olabilir).
/// EKRANKAYDI_DATA_DIR ortam değişkeni ile değiştirilebilir (testler bunu kullanır).
/// </summary>
public static class AppPaths
{
    public const string DataDirEnvVar = "EKRANKAYDI_DATA_DIR";

    public static string DataFolder
    {
        get
        {
            var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
            return !string.IsNullOrWhiteSpace(overrideDir)
                ? overrideDir
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EkranKaydi");
        }
    }

    public static string ThumbnailsFolder => Path.Combine(DataFolder, "thumbnails");
    public static string TempFolder => Path.Combine(DataFolder, "temp");
    public static string TempRecordingPath => Path.Combine(TempFolder, "temp_recording.mp4");
}
