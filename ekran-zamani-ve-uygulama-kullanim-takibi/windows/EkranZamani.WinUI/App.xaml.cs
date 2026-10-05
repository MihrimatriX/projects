using EkranZamani.Services;
using EkranZamani_WinUI.Services;
using Microsoft.UI.Xaml;

namespace EkranZamani_WinUI;

public partial class App : Application
{
    public static Window Window { get; private set; } = null!;
    public static Microsoft.UI.Dispatching.DispatcherQueue DispatcherQueue { get; private set; } = null!;

    public App()
    {
        InitializeComponent();
        UnhandledException += (_, e) =>
        {
            System.Diagnostics.Debug.WriteLine($"Unhandled: {e.Exception}");
            e.Handled = true;
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        if (!SingleInstanceService.TryBecomePrimaryInstance())
        {
            SingleInstanceService.SignalExistingInstance();
            Exit();
            return;
        }

        // ponytail: theme during Initialize() runs before Window — WinUI throws; apply after window
        AppServices.ApplyTheme = _ => { };
        AppServices.Initialize();
        AppServices.ApplyTheme = WinUiThemeService.Apply;

        Window = new MainWindow();
        DispatcherQueue = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        WinUiThemeService.Apply(AppServices.Settings.Current.Theme);

        SingleInstanceService.StartShowListener(
            () => DispatcherQueue.TryEnqueue(() => (Window as MainWindow)?.EnsureVisible()),
            action => DispatcherQueue.TryEnqueue(() => action()));

        if (Window is MainWindow main)
            main.EnsureVisible();
    }
}
