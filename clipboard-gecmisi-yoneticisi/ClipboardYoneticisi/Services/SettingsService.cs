using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace ClipboardYoneticisi.Services
{
    public class AppSettings
    {
        public int HistoryLimit { get; set; } = 500;
        public bool ExcludeSensitiveApps { get; set; } = true;
        public List<string> ExcludedProcessNames { get; set; } =
        [
            "1Password",
            "keepass",
            "KeePass",
            "bitwarden",
            "LastPass",
            "dashlane",
            "Enpass",
            "Authy",
            "winauth",
            "nordpass",
            "RoboForm"
        ];
        public bool StartMinimized { get; set; } = true;
        public bool StartWithWindows { get; set; } = false;
        public bool AutoPasteAfterSelect { get; set; } = false;
        public string ShowHotkey { get; set; } = "Ctrl+Alt+V";
        public string StackHotkey { get; set; } = "Ctrl+Alt+Shift+V";
        public bool EnableTrayNotifications { get; set; } = true;
        public bool NotifyOnCapture { get; set; } = true;
        public bool NotifyOnStackPaste { get; set; } = true;
        public bool BlurSensitiveContent { get; set; } = true;
        public bool FirstRunCompleted { get; set; } = false;
        public bool EnableOcr { get; set; } = true;
        public bool EnableEncryption { get; set; } = false;
        public int AutoDeleteDays { get; set; } = 0;
        public List<string> RegexFilterPatterns { get; set; } =
        [
            @"^\d{16}$",
            @"(?i)password\s*[:=]",
            @"(?i)cvv\s*[:=]"
        ];
        public bool CheckForUpdates { get; set; } = true;
        public string UpdateFeedUrl { get; set; } = string.Empty;
        public DateTime? LastUpdateCheckUtc { get; set; }
        public double? PanelLeft { get; set; }
        public double? PanelTop { get; set; }
    }

    public class SettingsService
    {
        private static SettingsService? _instance;

        public static SettingsService Instance => _instance ??= new SettingsService();

        private readonly string _settingsPath;

        public AppSettings Settings { get; private set; }

        private SettingsService()
        {
            AppPaths.EnsureDirectories();
            _settingsPath = AppPaths.SettingsPath;
            Settings = Load();
        }

        private AppSettings Load()
        {
            if (!File.Exists(_settingsPath))
                return new AppSettings();

            try
            {
                var json = File.ReadAllText(_settingsPath);
                return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Settings load failed: {ex.Message}");
                return new AppSettings();
            }
        }

        public void Save()
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(Settings, options);
            File.WriteAllText(_settingsPath, json);
            Helpers.RegexFilterService.InvalidateCache();
        }
    }
}
