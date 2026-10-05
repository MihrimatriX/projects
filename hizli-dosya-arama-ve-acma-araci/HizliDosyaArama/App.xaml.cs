using System;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
using HizliDosyaArama.Services;

namespace HizliDosyaArama;

public partial class App : System.Windows.Application
{
    private const string ShowEventName = "HizliDosyaArama_ShowPalette";
    private static Mutex? _mutex;
    private EventWaitHandle? _showEvent;

    protected override void OnStartup(StartupEventArgs e)
    {
        // Tek örnek: ikinci açılış yeni tepsi simgesi/indeksleyici başlatmak yerine çalışan örneğin paletini açar.
        _mutex = new Mutex(true, "HizliDosyaArama_SingleInstance", out bool isNew);
        if (!isNew)
        {
            try { EventWaitHandle.OpenExisting(ShowEventName).Set(); }
            catch (WaitHandleCannotBeOpenedException) { /* ilk örnek henüz hazır değil */ }
            // WPF Shutdown() burada ~10 sn bekletiyordu; henüz pencere/kaynak yokken süreç doğrudan sonlandırılır.
            Environment.Exit(0);
            return;
        }

        var showEvent = _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
        new Thread(() =>
        {
            while (showEvent.WaitOne())
                Dispatcher.BeginInvoke(() => (MainWindow as MainWindow)?.ShowPalette());
        }) { IsBackground = true }.Start();

        DispatcherUnhandledException += (_, args) =>
        {
            LogCrash(args.Exception);
            System.Windows.MessageBox.Show(
                $"Beklenmeyen bir hata oluştu. Ayrıntılar şu dosyaya yazıldı:\n{CrashLogPath}",
                "Hızlı Dosya Arama",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            args.Handled = true;
        };

        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            if (args.ExceptionObject is Exception ex)
                LogCrash(ex);
        };

        base.OnStartup(e);
    }

    private static string CrashLogPath => Path.Combine(DatabaseService.ResolveDataFolder(), "crash.log");

    private static void LogCrash(Exception ex)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(CrashLogPath)!);
            File.AppendAllText(CrashLogPath, $"[{DateTime.Now:O}] {ex}\n\n");
        }
        catch
        {
            // ponytail: log yazılamazsa sessiz kal
        }
    }
}
