namespace SistemYoneticisi.Services;

public static class AppPaths
{
    /// <summary>Veri klasörünü geçersiz kılar (testler ve taşınabilir kullanım için).</summary>
    public const string DataDirEnvVar = "SISTEM_YONETICISI_DATA_DIR";

    public static string AppDataDir { get; } = ResolveDataDir();

    public static string SettingsFile => Path.Combine(AppDataDir, "settings.json");
    public static string HistoryDb => Path.Combine(AppDataDir, "metrics.db");
    public static string LogFile => Path.Combine(AppDataDir, "app.log");
    public static string StartupBackupDir => Path.Combine(AppDataDir, "startup-backup");

    private static string ResolveDataDir()
    {
        var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
        if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir;
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SistemYoneticisiPaketi");
    }

    public static void EnsureDirectories()
    {
        Directory.CreateDirectory(AppDataDir);
    }
}
