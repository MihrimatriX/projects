using System.Text.Json;

namespace SistemYoneticisi.Services;

public sealed class SettingsService
{
    public static SettingsService Instance { get; } = new();

    public AppSettings Settings { get; set; } = new();

    private SettingsService()
    {
        Load();
    }

    public void Load()
    {
        try
        {
            AppPaths.EnsureDirectories();
            if (!File.Exists(AppPaths.SettingsFile)) return;

            var json = File.ReadAllText(AppPaths.SettingsFile);
            var loaded = JsonSerializer.Deserialize<AppSettings>(json);
            if (loaded != null)
                Settings = loaded;
        }
        catch (Exception ex)
        {
            LogService.Error("Settings load failed", ex);
        }
    }

    public void Save()
    {
        try
        {
            AppPaths.EnsureDirectories();
            var json = JsonSerializer.Serialize(Settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(AppPaths.SettingsFile, json);
        }
        catch (Exception ex)
        {
            LogService.Error("Settings save failed", ex);
        }
    }

    public void ExportTo(string filePath)
    {
        var json = JsonSerializer.Serialize(Settings, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(filePath, json);
    }

    public bool TryImportFrom(string filePath)
    {
        try
        {
            var json = File.ReadAllText(filePath);
            var loaded = JsonSerializer.Deserialize<AppSettings>(json);
            if (loaded == null)
                return false;

            loaded.WelcomeShown = Settings.WelcomeShown;
            Settings = loaded;
            Save();
            return true;
        }
        catch (Exception ex)
        {
            LogService.Error("Settings import failed", ex);
            return false;
        }
    }
}
