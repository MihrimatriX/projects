using System.IO;
using System.Text.Json;

namespace DosyaSifreleme.Services;

/// <summary>
/// Kasa dışındaki küçük tercihler (son kasa ve çıkarma klasörü, otomatik kilit süresi). Parola/anahtar asla yazılmaz.
/// Konum: %LOCALAPPDATA%\DosyaSifreleme\settings.json; testler DOSYA_SIFRELEME_DATA_DIR ile yönlendirir.
/// </summary>
public sealed class AppSettings
{
    public static readonly int[] AutoLockChoices = [1, 5, 15, 30];

    public string LastVaultPath { get; set; } = string.Empty;
    public int AutoLockMinutes { get; set; } = 5;
    public string LastExportFolder { get; set; } = string.Empty;

    public static string DataDir =>
        Environment.GetEnvironmentVariable("DOSYA_SIFRELEME_DATA_DIR") is { Length: > 0 } dir
            ? dir
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DosyaSifreleme");

    private static string FilePath => Path.Combine(DataDir, "settings.json");

    public static AppSettings Load()
    {
        try
        {
            var s = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath)) ?? new AppSettings();
            if (!AutoLockChoices.Contains(s.AutoLockMinutes)) s.AutoLockMinutes = 5;
            return s;
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            return new AppSettings(); // yok/bozuk: varsayılanlar
        }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            var tmp = FilePath + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
            File.Move(tmp, FilePath, overwrite: true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { } // tercih kaybı kasayı etkilemez
    }

    /// <summary>Test kancası: DOSYA_SIFRELEME_AUTOLOCK_SECONDS verilirse dakika ayarını geçersiz kılar.</summary>
    public int AutoLockSeconds =>
        int.TryParse(Environment.GetEnvironmentVariable("DOSYA_SIFRELEME_AUTOLOCK_SECONDS"), out var s) && s > 0
            ? s
            : AutoLockMinutes * 60;
}
