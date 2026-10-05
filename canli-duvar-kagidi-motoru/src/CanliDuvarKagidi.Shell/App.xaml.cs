using CanliDuvarKagidi_Shell.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace CanliDuvarKagidi_Shell;

public sealed partial class App : Application
{
    private MainWindow? _window;
    private static TrayIconService? _tray;

    public App()
    {
        // Oynaticilarin .NET WebView2 derlemeleri wv2\ altinda (bkz. Shell.csproj); kok klasordeki ayni adli
        // Microsoft.Web.WebView2.Core.dll yerel WinRT bilesenidir ve .NET derlemesi olarak yuklenemez.
        System.Runtime.Loader.AssemblyLoadContext.Default.Resolving += (ctx, name) =>
        {
            if (name.Name?.StartsWith("Microsoft.Web.WebView2.", StringComparison.Ordinal) != true) return null;
            var path = Path.Combine(AppContext.BaseDirectory, "wv2", name.Name + ".dll");
            return File.Exists(path) ? ctx.LoadFromAssemblyPath(path) : null;
        };
        InitializeComponent();
        RequestedTheme = ApplicationTheme.Dark;
        AppServices.Initialize();
        AppDomain.CurrentDomain.ProcessExit += (_, _) => Cleanup();
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _tray = new TrayIconService(_window);
        _window.Closed += OnWindowClosed;
        _window.Activate();
        try
        {
            await AppServices.RunStartupAsync();
        }
        catch
        {
            // ornek kurulumu / geri yukleme basarisiz olsa da uygulama acik kalsin
        }
    }

    private void OnWindowClosed(object sender, WindowEventArgs args)
    {
        // Arayuz testlerinde pencereyi kapatmak uygulamayi kapatir (tepsiye gizlenmez)
        if (AppServices.UiTestMode)
        {
            Exit();
            return;
        }

        args.Handled = true;
        _window?.AppWindow.Hide();
    }

    private static void Cleanup()
    {
        _tray?.Dispose(); // aksi halde cikista tepside hayalet simge kalir
        AppServices.ExplorerReconnect.Dispose();
        AppServices.Engine.Dispose();
        AppServices.Http.Dispose();
    }
}
