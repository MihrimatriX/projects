using EkranZamani_WinUI.ViewModels;
using EkranZamani.Services;
using EkranZamani_WinUI.Services;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Windows.Graphics;

namespace EkranZamani_WinUI;

public sealed partial class MainWindow : Window
{
    private bool _explicitExit;
    private readonly WinUiTrayService _tray = new();

    public MainWindow()
    {
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        AppWindow.SetIcon("Assets/AppIcon.ico");
        AppWindow.Resize(new SizeInt32(1200, 760));
        CenterOnScreen();

        RootFrame.Navigate(typeof(ShellPage));

        AppWindow.Closing += (_, e) =>
        {
            if (_explicitExit) return;
            if (AppServices.Settings.Current.MinimizeToTrayOnClose)
            {
                e.Cancel = true;
                HideToTray();
            }
        };
    }

    public void EnsureVisible()
    {
        AppWindow.Show();
        CenterOnScreen();
        Activate();
    }

    public void InitializeShell(DailyPageViewModel dailyViewModel)
    {
        try
        {
            WinUiAppHost.Configure(this, _tray, dailyViewModel);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Shell init: {ex.Message}");
        }

        // Tray + hotkeys after UI settles (Win32 notify + RegisterHotKey during Loaded = flaky)
        App.DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () =>
        {
            try { _tray.Initialize(ShowFromTray, () => AppTracking.Instance.Toggle(), ExitApplication); }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Tray: {ex.Message}"); }
        });
    }

    public void ShowFromTray()
    {
        AppWindow.Show();
        Activate();
    }

    public void HideToTray() => AppWindow.Hide();

    public void ExitApplication()
    {
        _explicitExit = true;
        try { AppTracking.Instance.Tracking.Stop(); } catch { /* ignore */ }
        WinUiAppHost.Shutdown();
        AppServices.Shutdown();
        _tray.Dispose();
        Application.Current.Exit();
    }

    private void CenterOnScreen()
    {
        var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary);
        if (area == null) return;
        var work = area.WorkArea;
        var size = AppWindow.Size;
        AppWindow.Move(new PointInt32(
            work.X + Math.Max(0, (work.Width - size.Width) / 2),
            work.Y + Math.Max(0, (work.Height - size.Height) / 2)));
    }
}
