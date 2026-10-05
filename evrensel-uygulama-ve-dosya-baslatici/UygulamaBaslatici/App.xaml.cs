using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows;
using UygulamaBaslatici.Services;

namespace UygulamaBaslatici;

public partial class App : Application
{
    private static Mutex? _mutex;
    private static EventWaitHandle? _showEvent;

    [DllImport("user32.dll")]
    private static extern bool AllowSetForegroundWindow(int processId);

    protected override void OnStartup(StartupEventArgs e)
    {
        // Tek örnek veri klasörü başına: testler (KOMUT_PALETI_DATA_DIR) kullanıcının açık örneğiyle çakışmaz.
        var key = InstanceKey(DatabaseService.ResolveDataFolder());
        _mutex = new Mutex(true, key, out bool isNew);
        _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, key + "_Show");
        if (!isNew)
        {
            // Exe ikinci kez çalıştırılınca açık örnek paleti gösterir (eskiden yalnızca uyarı kutusu çıkardı).
            AllowSetForegroundWindow(-1);
            _showEvent.Set();
            Shutdown();
            return;
        }

        ShutdownMode = ShutdownMode.OnExplicitShutdown;
        base.OnStartup(e);

        var window = new MainWindow();
        MainWindow = window;
        ThreadPool.RegisterWaitForSingleObject(_showEvent,
            (_, _) => Dispatcher.BeginInvoke(window.ShowPalette), null, Timeout.Infinite, executeOnlyOnce: false);
    }

    internal static string InstanceKey(string dataFolder) =>
        "KomutPaleti_" + Convert.ToHexString(SHA256.HashData(
            Encoding.UTF8.GetBytes(System.IO.Path.GetFullPath(dataFolder).TrimEnd('\\').ToUpperInvariant())))[..16];
}
