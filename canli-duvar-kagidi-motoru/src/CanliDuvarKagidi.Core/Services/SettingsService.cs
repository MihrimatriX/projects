using System.Text.Json;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public sealed class AppPaths
{
    public const string DataDirEnvVar = "CANLI_DUVAR_DATA";

    public string Root { get; }
    public string Installed => Path.Combine(Root, "installed");
    public string Cache => Path.Combine(Root, "cache");
    public string SettingsFile => Path.Combine(Root, "settings.json");

    public AppPaths(string? root = null)
    {
        // Ortam degiskeni: duman testi gercek kullanici verisine dokunmadan calissin
        var fromEnv = Environment.GetEnvironmentVariable(DataDirEnvVar);
        Root = root
            ?? (string.IsNullOrWhiteSpace(fromEnv) ? null : fromEnv)
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "CanliDuvarKagidi");
        Directory.CreateDirectory(Installed);
        Directory.CreateDirectory(Cache);
    }
}

public sealed class SettingsService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly AppPaths _paths;

    public SettingsService(AppPaths paths) => _paths = paths;

    public UserSettings Load()
    {
        if (!File.Exists(_paths.SettingsFile))
            return new UserSettings();

        try
        {
            var json = File.ReadAllText(_paths.SettingsFile);
            var settings = JsonSerializer.Deserialize<UserSettings>(json) ?? new UserSettings();
            settings.MonitorWallpapers ??= new();
            return settings;
        }
        catch (JsonException)
        {
            // Bozuk dosya acilisi cokertmesin: kenara al (incelenebilsin), varsayilanlarla devam et
            File.Move(_paths.SettingsFile, _paths.SettingsFile + ".bozuk", overwrite: true);
            return new UserSettings();
        }
    }

    public void Save(UserSettings settings)
    {
        // Gecici dosyaya yazip yer degistir: yazma sirasinda cokme ayarlari yarim birakmasin
        var temp = _paths.SettingsFile + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(settings, JsonOptions));
        File.Move(temp, _paths.SettingsFile, overwrite: true);
    }
}
