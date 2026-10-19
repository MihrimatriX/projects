using System;
using System.Windows;
using EkranRenkSecici.Helpers;

namespace EkranRenkSecici;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        ShutdownMode = ShutdownMode.OnExplicitShutdown;
        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show(args.Exception.Message, "Beklenmeyen hata", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            if (args.ExceptionObject is Exception ex)
            {
                MessageBox.Show(ex.Message, "Kritik hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        };

        base.OnStartup(e);
    }
}
