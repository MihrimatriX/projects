using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ClipboardYoneticisi.Services;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Conditions;
using FlaUI.UIA3;
using Application = FlaUI.Core.Application;
using Window = FlaUI.Core.AutomationElements.Window;

namespace ClipboardYoneticisi.Tests;

/// <summary>
/// Gecici veri klasorunde gercek ClipboardGecmisiYoneticisi.exe'yi acar. Kullanicinin verisine,
/// kayit defterine (otomatik baslatma) ve tek-ornek kilidine dokunulmaz (CLIPBOARD_GECMISI_DATA_DIR).
/// </summary>
internal sealed class AppUnderTest : IDisposable
{
    public const string ShowHotkey = "Ctrl+Alt+Shift+F9";
    public const string StackHotkey = "Ctrl+Alt+Shift+F10";

    public string DataDir { get; } = Path.Combine(Path.GetTempPath(), "cgy-ui-" + Guid.NewGuid().ToString("N"));
    public UIA3Automation Automation { get; } = new();
    public Application App { get; }
    public int Pid => App.ProcessId;

    public AppUnderTest(bool firstRun = false, bool startHidden = false)
    {
        Directory.CreateDirectory(DataDir);
        File.WriteAllText(Path.Combine(DataDir, "settings.json"), JsonSerializer.Serialize(new AppSettings
        {
            FirstRunCompleted = !firstRun,
            StartMinimized = startHidden,
            CheckForUpdates = false,
            EnableOcr = false,
            EnableTrayNotifications = false,
            ShowHotkey = ShowHotkey,
            StackHotkey = StackHotkey,
            // Test icerigi "hassas" sayilip gizlenmesin (onizleme metnine gore arama yapiyoruz).
            BlurSensitiveContent = false,
        }));
        App = Application.Launch(StartInfo());
    }

    public ProcessStartInfo StartInfo()
    {
        var exe = Path.Combine(AppContext.BaseDirectory, "ClipboardGecmisiYoneticisi.exe");
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false, WorkingDirectory = DataDir };
        psi.Environment["CLIPBOARD_GECMISI_DATA_DIR"] = DataDir;
        psi.Environment["CLIPBOARD_GECMISI_TEST"] = "1";
        return psi;
    }

    public AppSettings Settings() =>
        JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(Path.Combine(DataDir, "settings.json")))!;

    public ConditionFactory Cf => Automation.ConditionFactory;

    /// <summary>
    /// Bu surecin penceresi (WPF diyaloglari, MessageBox, ortak dosya diyaloglari). Sahipli (Owner) pencereler
    /// UIA agacinda sahibinin altinda gorunur; bu yuzden ust duzey pencerelerin icine de bakilir.
    /// </summary>
    public Window? TopWindow(string title)
    {
        foreach (var w in Automation.GetDesktop().FindAllChildren(Cf.ByProcessId(Pid)))
        {
            if (w.Properties.Name.ValueOrDefault == title && w.ControlType == FlaUI.Core.Definitions.ControlType.Window)
                return w.AsWindow();
            if (w.FindFirstDescendant(Cf.ByControlType(FlaUI.Core.Definitions.ControlType.Window).And(Cf.ByName(title))) is { } owned)
                return owned.AsWindow();
        }
        return null;
    }

    /// <summary>Pencere icinde (alt ogelerde) metni iceren bir oge var mi.</summary>
    public static bool HasText(AutomationElement root, string text) =>
        root.FindAllDescendants().Any(e => (e.Properties.Name.ValueOrDefault ?? "").Contains(text));

    public Window WaitWindow(string title) => Ui.Retry(() => TopWindow(title), "pencere: " + title);

    public void Dispose()
    {
        try
        {
            if (!App.HasExited) App.Kill();
            App.WaitWhileBusy(TimeSpan.FromSeconds(2));
        }
        catch { /* zaten kapandi */ }
        App.Dispose();
        Automation.Dispose();
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        if (Environment.GetEnvironmentVariable("CGY_KEEP_DATA") != null) return; // hata ayiklama: log/db kalsin
        for (var i = 0; i < 10 && Directory.Exists(DataDir); i++)
        {
            try { Directory.Delete(DataDir, recursive: true); }
            catch (IOException) { Thread.Sleep(200); }
            catch (UnauthorizedAccessException) { Thread.Sleep(200); }
        }
    }
}

internal static class Ui
{
    public static T Retry<T>(Func<T?> f, string what, double seconds = 10) where T : class
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(seconds))
        {
            try
            {
                if (f() is { } r) return r;
            }
            catch (COMException) { /* UIA agaci degisirken */ }
            Thread.Sleep(100);
        }
        throw new TimeoutException("Bulunamadi: " + what);
    }

    public static void Wait(Func<bool> cond, string what, double seconds = 10)
    {
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try
            {
                if (cond()) return;
            }
            catch (COMException) { }
            catch (FlaUI.Core.Exceptions.PropertyNotSupportedException) { }
            if (sw.Elapsed > TimeSpan.FromSeconds(seconds)) throw new TimeoutException("Beklenen durum olusmadi: " + what);
            Thread.Sleep(100);
        }
    }

    /// <summary>
    /// Modal diyalog acan komutlar UIA Invoke cagrisini diyalog kapanana kadar bekletebilir; arka planda cagir.
    /// </summary>
    public static void InvokeNoWait(AutomationElement e) => _ = Task.Run(() =>
    {
        try { e.Patterns.Invoke.Pattern.Invoke(); } catch { /* diyalog acikken zaman asimi olabilir */ }
    });

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, IntPtr pid);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();

    /// <summary>
    /// Baska bir surec on plandayken SetForegroundWindow reddedilir; on plan is parcacigina gecici baglanip dene
    /// (tus gondermeden; Alt hilesi diger uygulamalarin menusunu acabilirdi).
    /// </summary>
    public static void ForceForeground(IntPtr hwnd)
    {
        var fgThread = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        var me = GetCurrentThreadId();
        var attached = fgThread != 0 && fgThread != me && AttachThreadInput(me, fgThread, true);
        try
        {
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
        }
        finally
        {
            if (attached) AttachThreadInput(me, fgThread, false);
        }
    }

    [DllImport("user32.dll")]
    private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);

    /// <summary>PrintWindow(PW_RENDERFULLCONTENT) ile pencereyi PNG'ye yazar (ekran kopyalamaz, kilit gerekmez).</summary>
    public static void SaveWindowPng(Window w, string path)
    {
        var r = w.BoundingRectangle;
        using var bmp = new System.Drawing.Bitmap(r.Width, r.Height);
        using (var g = System.Drawing.Graphics.FromImage(bmp))
        {
            var hdc = g.GetHdc();
            PrintWindow(w.Properties.NativeWindowHandle.Value, hdc, 2);
            g.ReleaseHdc(hdc);
        }
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    }
}

/// <summary>Pano islemleri STA is parcaciginda (WPF Clipboard gereksinimi), mesgul panoya karsi tekrar denemeli.</summary>
internal static class Pano
{
    public static void Sta(Action action)
    {
        Exception? error = null;
        var t = new Thread(() =>
        {
            for (var i = 0; ; i++)
            {
                try { action(); return; }
                catch (COMException) when (i < 100) { Thread.Sleep(50); } // pano baska surecte acik olabilir
                catch (Exception ex) { error = ex; return; }
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        if (error != null) throw error;
    }

    /// <summary>
    /// Test verisi: uygulamanin test isareti (yalnizca gecici klasorlu ornek kaydeder) +
    /// Windows pano gecmisine (Win+V) girmesin.
    /// </summary>
    public static DataObject Marked()
    {
        var o = new DataObject();
        o.SetData(ClipboardMonitorService.TestMarkerFormat, "1");
        o.SetData("CanIncludeInClipboardHistory", new MemoryStream(BitConverter.GetBytes(0)));
        o.SetData("CanUploadToCloudClipboard", new MemoryStream(BitConverter.GetBytes(0)));
        return o;
    }

    public static void CopyText(string text) => Sta(() =>
    {
        var o = Marked();
        o.SetText(text);
        Clipboard.SetDataObject(o, true);
    });

    public static void CopyDemoImage() => Sta(() =>
    {
        const int w = 240, h = 150;
        var pixels = new byte[w * h * 4];
        for (var y = 0; y < h; y++)
        for (var x = 0; x < w; x++)
        {
            var i = (y * w + x) * 4;
            pixels[i] = (byte)(160 + 95 * x / w);     // B
            pixels[i + 1] = (byte)(90 + 120 * y / h); // G
            pixels[i + 2] = (byte)(200 - 120 * x / w); // R
            pixels[i + 3] = 255;
        }
        var bmp = BitmapSource.Create(w, h, 96, 96, PixelFormats.Bgra32, null, pixels, w * 4);
        var o = Marked();
        o.SetImage(bmp);
        Clipboard.SetDataObject(o, true);
    });

    public static string? Text()
    {
        string? text = null;
        Sta(() => text = Clipboard.ContainsText() ? Clipboard.GetText() : null);
        return text;
    }
}

/// <summary>
/// UI testleri panoyu degistirir: once kullanicinin pano icerigini (tum okunabilir bicimler) saklar,
/// testler bitince geri yazar. Geri yazilan veri de isaretlidir, kullanicinin gercek ornegi tekrar kaydetmez.
/// ponytail: gecikmeli olusturulan / okunamayan bicimler (bazi uygulamalarin ozel bicimleri) atlanir.
/// </summary>
public sealed class ClipboardSnapshot : IDisposable
{
    private readonly List<(string Format, object Data)> _items = [];

    public ClipboardSnapshot() => Pano.Sta(() =>
    {
        if (Clipboard.GetDataObject() is not { } d) return;
        foreach (var f in d.GetFormats(autoConvert: false))
        {
            try
            {
                if (d.GetData(f, autoConvert: false) is { } v) _items.Add((f, v));
            }
            catch { /* okunamayan bicim */ }
        }
    });

    public void Dispose() => Pano.Sta(() =>
    {
        // Testten sonra baska bir surec panoya yazdiysa onun icerigini ezme.
        if (Clipboard.GetDataObject() is { } now && !now.GetDataPresent(ClipboardMonitorService.TestMarkerFormat))
            return;
        if (_items.Count == 0)
        {
            Clipboard.Clear();
            return;
        }
        var o = Pano.Marked();
        foreach (var (f, v) in _items)
        {
            try { o.SetData(f, v); } catch { /* yazilamayan bicim */ }
        }
        Clipboard.SetDataObject(o, true);
    });
}

/// <summary>Repo kokundeki .gui.lock: agent'lar masaustunu paylasir; gercek girdi yalnizca kilit icinde.</summary>
internal static class GuiLock
{
    public static FileStream Acquire()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "launcher.ps1")))
            dir = dir.Parent;
        var path = Path.Combine(dir?.FullName ?? Path.GetTempPath(), ".gui.lock");
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException) when (sw.Elapsed < TimeSpan.FromMinutes(5)) { Thread.Sleep(500); }
        }
    }
}
