using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows.Input;

namespace EkranGoruntusu.Services;

public sealed class SettingsService
{
    private readonly string _settingsPath;
    private AppSettings _settings;

    public SettingsService(string dataFolder)
    {
        Directory.CreateDirectory(dataFolder);
        _settingsPath = Path.Combine(dataFolder, "settings.json");
        _settings = Load();
    }

    public string SaveFolder
    {
        get => _settings.SaveFolder;
        set { _settings.SaveFolder = value; Save(); }
    }

    public string FilenameTemplate
    {
        get => _settings.FilenameTemplate;
        set { _settings.FilenameTemplate = value; Save(); }
    }

    // Global yakalama kısayolu: serbest giriş yerine hazır seçenekler (çakışmada kullanıcı başka birini seçer).
    public static readonly string[] HotkeyChoices = ["Ctrl+Alt+A", "Ctrl+Shift+A", "Ctrl+Alt+S", "Ctrl+Shift+S", "PrintScreen"];
    public const string DefaultHotkey = "Ctrl+Alt+A";

    public string Hotkey
    {
        get => _settings.Hotkey;
        set { _settings.Hotkey = value; Save(); }
    }

    // Geçmişte tutulacak kayıt sayısı; sınırı aşan en eski kayıtların PNG dosyaları da silinir.
    public static readonly int[] HistoryLimitChoices = [20, 50, 100, 500];

    public int HistoryLimit
    {
        get => _settings.HistoryLimit;
        set { _settings.HistoryLimit = value; Save(); }
    }

    public static bool TryParseHotkey(string text, out Key key, out ModifierKeys modifiers)
    {
        key = Key.None;
        modifiers = ModifierKeys.None;
        foreach (var part in text.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            switch (part)
            {
                case "Ctrl": modifiers |= ModifierKeys.Control; break;
                case "Alt": modifiers |= ModifierKeys.Alt; break;
                case "Shift": modifiers |= ModifierKeys.Shift; break;
                case "PrintScreen": key = Key.PrintScreen; break;
                default:
                    if (key != Key.None || !Enum.TryParse(part, out key)) return false;
                    break;
            }
        }
        return key != Key.None;
    }

    /// <summary>Kullanıcıya gösterilen biçim: "Ctrl + Alt + A".</summary>
    public static string DisplayHotkey(string hotkey) => hotkey.Replace("+", " + ");

    public string FormatFilename(DateTime timestamp)
    {
        var template = FilenameTemplate;
        return template
            .Replace("{yyyy}", timestamp.ToString("yyyy", CultureInfo.InvariantCulture))
            .Replace("{MM}", timestamp.ToString("MM", CultureInfo.InvariantCulture))
            .Replace("{dd}", timestamp.ToString("dd", CultureInfo.InvariantCulture))
            .Replace("{HH}", timestamp.ToString("HH", CultureInfo.InvariantCulture))
            .Replace("{mm}", timestamp.ToString("mm", CultureInfo.InvariantCulture))
            .Replace("{ss}", timestamp.ToString("ss", CultureInfo.InvariantCulture))
            + ".png";
    }

    // Veriler exe yanına değil kullanıcı profiline yazılır; testler/taşınabilir kullanım için ortam değişkeniyle değiştirilebilir.
    public const string DataDirEnvVar = "EKRAN_GORUNTUSU_DATA_DIR";

    public static string ResolveDataFolder()
    {
        var overrideDir = Environment.GetEnvironmentVariable(DataDirEnvVar);
        if (!string.IsNullOrWhiteSpace(overrideDir)) return overrideDir;

        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GelismisEkranGoruntusu");
        MigrateLegacyData(Path.Combine(AppContext.BaseDirectory, "data"), folder);
        return folder;
    }

    // Eski sürümler veriyi exe yanındaki data\ altında tutuyordu; yeni konum boşsa geçmiş ve ayarlar kopyalanır
    // (görsel yolları mutlak olduğundan PNG'ler yerinde kalır).
    internal static void MigrateLegacyData(string legacyFolder, string targetFolder)
    {
        try
        {
            if (File.Exists(Path.Combine(targetFolder, "screenshots.db")) ||
                !File.Exists(Path.Combine(legacyFolder, "screenshots.db")))
                return;

            Directory.CreateDirectory(targetFolder);
            foreach (var name in new[] { "screenshots.db", "settings.json" })
            {
                var src = Path.Combine(legacyFolder, name);
                if (File.Exists(src)) File.Copy(src, Path.Combine(targetFolder, name));
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            System.Diagnostics.Debug.WriteLine($"Legacy data migration failed: {ex.Message}");
        }
    }

    public static bool IsValidTemplate(string template) =>
        template.IndexOfAny(Path.GetInvalidFileNameChars()) < 0 &&
        (template.Contains("{yyyy}", StringComparison.Ordinal) ||
        template.Contains("{MM}", StringComparison.Ordinal) ||
        template.Contains("{dd}", StringComparison.Ordinal) ||
        template.Contains("{HH}", StringComparison.Ordinal) ||
        template.Contains("{mm}", StringComparison.Ordinal) ||
        template.Contains("{ss}", StringComparison.Ordinal));

    public void Reset()
    {
        _settings = AppSettings.CreateDefault(Path.GetDirectoryName(_settingsPath)!);
        Save();
    }

    private AppSettings Load()
    {
        var dataFolder = Path.GetDirectoryName(_settingsPath)!;
        if (!File.Exists(_settingsPath))
            return AppSettings.CreateDefault(dataFolder);

        try
        {
            var json = File.ReadAllText(_settingsPath);
            var loaded = JsonSerializer.Deserialize<AppSettings>(json);
            if (loaded == null || string.IsNullOrWhiteSpace(loaded.SaveFolder))
                return AppSettings.CreateDefault(dataFolder);
            // Eski ayar dosyalarında bu alanlar yok ya da elle bozulmuş olabilir.
            if (!HotkeyChoices.Contains(loaded.Hotkey)) loaded.Hotkey = DefaultHotkey;
            if (!HistoryLimitChoices.Contains(loaded.HistoryLimit)) loaded.HistoryLimit = HistoryLimitChoices[0];
            return loaded;
        }
        catch
        {
            return AppSettings.CreateDefault(dataFolder);
        }
    }

    private void Save()
    {
        var json = JsonSerializer.Serialize(_settings, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_settingsPath, json);
    }

    private sealed class AppSettings
    {
        public string SaveFolder { get; set; } = "";
        public string FilenameTemplate { get; set; } = "{yyyy}-{MM}-{dd}_{HH}{mm}{ss}";
        public string Hotkey { get; set; } = DefaultHotkey;
        public int HistoryLimit { get; set; } = 20;

        public static AppSettings CreateDefault(string dataFolder) => new()
        {
            SaveFolder = Path.Combine(dataFolder, "screenshots"),
            FilenameTemplate = "{yyyy}-{MM}-{dd}_{HH}{mm}{ss}"
        };
    }
}
