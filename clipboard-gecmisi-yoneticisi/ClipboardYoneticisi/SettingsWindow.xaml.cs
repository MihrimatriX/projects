using System;
using System.Linq;
using System.Windows;
using ClipboardYoneticisi.Helpers;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi
{
    public partial class SettingsWindow : Window
    {
        private readonly AppSettings _settings;
        private readonly bool _encryptionWasEnabled;
        public bool EncryptionChanged { get; private set; }

        public SettingsWindow()
        {
            InitializeComponent();
            _settings = SettingsService.Instance.Settings;
            _encryptionWasEnabled = _settings.EnableEncryption;

            HistoryLimitBox.Text = _settings.HistoryLimit.ToString();
            AutoDeleteDaysBox.Text = _settings.AutoDeleteDays.ToString();
            ShowHotkeyBox.Text = _settings.ShowHotkey;
            StackHotkeyBox.Text = _settings.StackHotkey;
            ExcludeSensitiveCheck.IsChecked = _settings.ExcludeSensitiveApps;
            StartMinimizedCheck.IsChecked = _settings.StartMinimized;
            StartWithWindowsCheck.IsChecked = _settings.StartWithWindows;
            AutoPasteCheck.IsChecked = _settings.AutoPasteAfterSelect;
            EnableTrayNotificationsCheck.IsChecked = _settings.EnableTrayNotifications;
            NotifyOnCaptureCheck.IsChecked = _settings.NotifyOnCapture;
            NotifyOnStackPasteCheck.IsChecked = _settings.NotifyOnStackPaste;
            EnableOcrCheck.IsChecked = _settings.EnableOcr;
            EnableEncryptionCheck.IsChecked = _settings.EnableEncryption;
            BlurSensitiveCheck.IsChecked = _settings.BlurSensitiveContent;
            CheckForUpdatesCheck.IsChecked = _settings.CheckForUpdates;
            UpdateFeedUrlBox.Text = _settings.UpdateFeedUrl;
            ExcludedAppsBox.Text = string.Join(Environment.NewLine, _settings.ExcludedProcessNames);
            RegexPatternsBox.Text = string.Join(Environment.NewLine, _settings.RegexFilterPatterns);
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            if (!int.TryParse(HistoryLimitBox.Text, out int limit) || limit < 10 || limit > 5000)
            {
                ShowWarning("Geçmiş limiti 10 ile 5000 arasında bir sayı olmalıdır.");
                return;
            }

            if (!int.TryParse(AutoDeleteDaysBox.Text, out int autoDeleteDays) || autoDeleteDays < 0 || autoDeleteDays > 3650)
            {
                ShowWarning("Otomatik silme 0 ile 3650 gün arasında olmalıdır.");
                return;
            }

            if (!HotkeyParser.TryParse(ShowHotkeyBox.Text, out _, out _))
            {
                ShowWarning("Panel kısayolu geçersiz. Örnek: Ctrl+Alt+V");
                return;
            }

            if (!HotkeyParser.TryParse(StackHotkeyBox.Text, out _, out _))
            {
                ShowWarning("Stack kısayolu geçersiz. Örnek: Ctrl+Alt+Shift+V");
                return;
            }

            if (string.Equals(ShowHotkeyBox.Text.Replace(" ", ""), StackHotkeyBox.Text.Replace(" ", ""), StringComparison.OrdinalIgnoreCase))
            {
                ShowWarning("Panel ve stack kısayolları farklı olmalıdır.");
                return;
            }

            var encryptionNow =EnableEncryptionCheck.IsChecked == true;

            _settings.HistoryLimit = limit;
            _settings.AutoDeleteDays = autoDeleteDays;
            _settings.ShowHotkey = ShowHotkeyBox.Text.Trim();
            _settings.StackHotkey = StackHotkeyBox.Text.Trim();
            _settings.ExcludeSensitiveApps = ExcludeSensitiveCheck.IsChecked == true;
            _settings.StartMinimized = StartMinimizedCheck.IsChecked == true;
            _settings.StartWithWindows = StartWithWindowsCheck.IsChecked == true;
            _settings.AutoPasteAfterSelect = AutoPasteCheck.IsChecked == true;
            _settings.EnableTrayNotifications = EnableTrayNotificationsCheck.IsChecked == true;
            _settings.NotifyOnCapture = NotifyOnCaptureCheck.IsChecked == true;
            _settings.NotifyOnStackPaste = NotifyOnStackPasteCheck.IsChecked == true;
            _settings.EnableOcr = EnableOcrCheck.IsChecked == true;
            _settings.EnableEncryption = encryptionNow;
            _settings.BlurSensitiveContent = BlurSensitiveCheck.IsChecked == true;
            _settings.CheckForUpdates = CheckForUpdatesCheck.IsChecked == true;
            _settings.UpdateFeedUrl = UpdateFeedUrlBox.Text.Trim();
            _settings.ExcludedProcessNames = ExcludedAppsBox.Text
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
                .Select(line => line.Trim())
                .Where(line => !string.IsNullOrEmpty(line))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            _settings.RegexFilterPatterns = RegexPatternsBox.Text
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
                .Select(line => line.Trim())
                .Where(line => !string.IsNullOrEmpty(line))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            SettingsService.Instance.Save();
            StartupService.SetEnabled(_settings.StartWithWindows);
            EncryptionChanged = encryptionNow != _encryptionWasEnabled;

            if (encryptionNow && !_encryptionWasEnabled)
            {
                var lockWindow = new LockWindow(isSetup: true) { Owner = this };
                if (lockWindow.ShowDialog() != true || string.IsNullOrWhiteSpace(lockWindow.EnteredPassword))
                {
                    _settings.EnableEncryption = false;
                    SettingsService.Instance.Save();
                    ShowWarning("Şifreli mod için parola belirlenmedi. Şifreleme devre dışı bırakıldı.");
                    return;
                }

                EncryptionService.Instance.SetupPassword(lockWindow.EnteredPassword);
            }

            DialogResult = true;
            Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void ShowWarning(string message) =>
            MessageBox.Show(message, "Geçersiz değer", MessageBoxButton.OK, MessageBoxImage.Warning);
    }
}
