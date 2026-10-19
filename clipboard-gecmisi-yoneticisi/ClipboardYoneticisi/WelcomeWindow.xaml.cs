using System.Windows;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi
{
    public partial class WelcomeWindow : Window
    {
        public WelcomeWindow()
        {
            InitializeComponent();
            StartWithWindowsCheck.IsChecked = SettingsService.Instance.Settings.StartWithWindows;
            ShowHotkeyRun.Text = SettingsService.Instance.Settings.ShowHotkey;
        }

        private void StartButton_Click(object sender, RoutedEventArgs e)
        {
            var settings = SettingsService.Instance.Settings;
            settings.FirstRunCompleted = true;
            settings.StartWithWindows = StartWithWindowsCheck.IsChecked == true;
            SettingsService.Instance.Save();
            StartupService.SetEnabled(settings.StartWithWindows);
            DialogResult = true;
            Close();
        }
    }
}
