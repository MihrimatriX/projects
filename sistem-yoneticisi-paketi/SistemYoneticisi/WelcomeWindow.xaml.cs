using System.Windows;
using SistemYoneticisi.Services;

namespace SistemYoneticisi;

public partial class WelcomeWindow : Window
{
    public WelcomeWindow()
    {
        InitializeComponent();
        RunAtLoginBox.IsChecked = LoginStartupService.IsEnabled();
    }

    private void Start_Click(object sender, RoutedEventArgs e)
    {
        var settings = SettingsService.Instance.Settings;
        settings.WelcomeShown = true;
        settings.RunAtLogin = RunAtLoginBox.IsChecked == true;
        SettingsService.Instance.Settings = settings;
        SettingsService.Instance.Save();
        LoginStartupService.SetEnabled(settings.RunAtLogin);
        DialogResult = true;
        Close();
    }
}
