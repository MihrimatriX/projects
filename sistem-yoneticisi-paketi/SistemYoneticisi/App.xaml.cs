using System.Windows;
using SistemYoneticisi.Services;

namespace SistemYoneticisi;

public partial class App : Application
{
    private SingleInstanceService? _singleInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        AppPaths.EnsureDirectories();
        LogService.Info("Application starting.");

        _singleInstance = new SingleInstanceService();
        if (!_singleInstance.IsFirstInstance)
        {
            Shutdown();
            return;
        }

        ThemeService.ApplyHighContrast(SettingsService.Instance.Settings.HighContrastMode);

        var mainWindow = new MainWindow();
        mainWindow.Show();
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        LogService.Info("Application exited.");
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
