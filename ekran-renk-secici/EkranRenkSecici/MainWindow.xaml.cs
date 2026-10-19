using System.ComponentModel;
using System.IO;
using System.Windows;
using EkranRenkSecici.ViewModels;

namespace EkranRenkSecici;

public partial class MainWindow : Window
{
    private bool _isShuttingDown;

    public MainWindow()
    {
        InitializeComponent();

        var vm = new MainViewModel();
        vm.RequestMainWindowShow += ShowFromTray;
        DataContext = vm;

        Loaded += (_, _) => Hide();

        var icon = LoadTrayIcon();
        if (icon != null) MyNotifyIcon.Icon = icon;

        // Gecici veri klasoruyle (test) calisan ornegin tepsi simgesi gercek ornekten ayirt edilebilsin.
        if (Environment.GetEnvironmentVariable("EKRAN_RENK_SECICI_DATA_DIR") is { Length: > 0 })
            MyNotifyIcon.ToolTipText += " (test)";

        Application.Current.SessionEnding += (_, _) => _isShuttingDown = true;
    }

    private static System.Drawing.Icon? LoadTrayIcon()
    {
        try
        {
            var exe = Environment.ProcessPath;
            if (!string.IsNullOrEmpty(exe))
            {
                var fromExe = System.Drawing.Icon.ExtractAssociatedIcon(exe);
                if (fromExe != null) return fromExe;
            }
        }
        catch { /* fall through */ }

        var icoPath = Path.Combine(AppContext.BaseDirectory, "app.ico");
        return File.Exists(icoPath) ? new System.Drawing.Icon(icoPath) : null;
    }

    private void ShowFromTray()
    {
        ShowInTaskbar = true;
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    public void PrepareForExit() => _isShuttingDown = true;

    // Pencere kapatılınca uygulama kapanmaz, tepsiye gizlenir (ShutdownMode=OnExplicitShutdown).
    // Gerçek çıkış yalnızca tepsi menüsündeki "Çıkış" veya oturum kapanışıyla olur.
    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_isShuttingDown)
        {
            e.Cancel = true;
            Hide();
            ShowInTaskbar = false;
            return;
        }

        MyNotifyIcon.Dispose();
        base.OnClosing(e);
    }
}
