using System;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi;

public partial class App : Application
{
    private SingleInstanceService? _singleInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        AppPaths.EnsureDirectories();
        AppPaths.MigrateLegacyDataIfNeeded();

        _singleInstance = new SingleInstanceService();
        if (!_singleInstance.IsFirstInstance)
        {
            Shutdown();
            return;
        }

        DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += OnDomainUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

        LogService.Info("Application started.");
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        LogService.Info("Application exited.");
        _singleInstance?.Dispose();
        base.OnExit(e);
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        LogService.Error("UI thread exception", e.Exception);
        MessageBox.Show(
            "Beklenmeyen bir hata oluştu. Ayrıntılar log dosyasına yazıldı.",
            "Hata",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }

    private static void OnDomainUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        if (e.ExceptionObject is Exception ex)
            LogService.Error("Unhandled domain exception", ex);
    }

    private static void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
    {
        LogService.Error("Unobserved task exception", e.Exception);
        e.SetObserved();
    }
}
