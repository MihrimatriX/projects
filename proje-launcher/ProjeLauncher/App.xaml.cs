using System.Windows;
using System.Windows.Threading;

namespace ProjeLauncher;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Beklenmeyen hata uygulamayi kapatmasin; kullaniciya gosterilir.
        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show(args.Exception.GetBaseException().ToString(), "DEV Projects", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
        };
        // Varsayilan: Windows acik/koyu temasi + vurgu rengi. DEVPROJECTS_THEME=Light|Dark ile zorlanabilir.
        if (Environment.GetEnvironmentVariable("DEVPROJECTS_THEME") is "Light" or "Dark")
            ThemeMode = new ThemeMode(Environment.GetEnvironmentVariable("DEVPROJECTS_THEME")!);
        base.OnStartup(e);
    }
}
