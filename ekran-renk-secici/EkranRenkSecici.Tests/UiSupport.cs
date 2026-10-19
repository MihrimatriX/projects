using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using EkranRenkSecici.Models;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.UIA3;
using Application = FlaUI.Core.Application;
using Window = FlaUI.Core.AutomationElements.Window;

namespace EkranRenkSecici.Tests;

/// <summary>Gercek EkranRenkSecici.exe'yi gecici veri klasoruyle (EKRAN_RENK_SECICI_DATA_DIR) acar.</summary>
internal sealed class AppUnderTest : IDisposable
{
    public const string HotkeyDisplay = "Ctrl+Shift+Alt+K";

    public string DataDir { get; } = Path.Combine(Path.GetTempPath(), "ers-ui-" + Guid.NewGuid().ToString("N"));
    public UIA3Automation Automation { get; } = new();
    public Application App { get; }
    public int Pid => App.ProcessId;

    public AppUnderTest()
    {
        Directory.CreateDirectory(DataDir);
        // Kullanicinin olasi Ctrl+Shift+C kisayoluyla cakismasin.
        File.WriteAllText(Path.Combine(DataDir, "settings.json"), JsonSerializer.Serialize(new AppSettings
        {
            HotkeyKey = "K",
            HotkeyModifiers = "Control,Shift,Alt",
        }));
        var psi = new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory, "EkranRenkSecici.exe"))
        {
            UseShellExecute = false,
            WorkingDirectory = DataDir,
        };
        psi.Environment["EKRAN_RENK_SECICI_DATA_DIR"] = DataDir;
        App = Application.Launch(psi);
    }

    public string SettingsJson => File.ReadAllText(Path.Combine(DataDir, "settings.json"));

    /// <summary>Surecin penceresi; sahipli diyaloglar sahibinin altinda da aranir.</summary>
    public Window? FindWindow(string title)
    {
        var cf = Automation.ConditionFactory;
        foreach (var w in Automation.GetDesktop().FindAllChildren(cf.ByProcessId(Pid)))
        {
            if (w.Properties.Name.ValueOrDefault == title && w.ControlType == ControlType.Window) return w.AsWindow();
            if (w.FindFirstDescendant(cf.ByControlType(ControlType.Window).And(cf.ByName(title))) is { } owned)
                return owned.AsWindow();
        }
        return null;
    }

    public Window WaitWindow(string title) => Ui.Retry(() => FindWindow(title), "pencere: " + title);

    /// <summary>Gorev cubugu ya da gizli simgeler tasmasindaki tepsi dugmesi.</summary>
    public AutomationElement TrayIcon()
    {
        const string name = "Ekran Renk Seçici (test)";
        var desktop = Automation.GetDesktop();
        AutomationElement? Find() =>
            new[] { "Shell_TrayWnd", "TopLevelWindowForOverflowXamlIsland" }
                .Select(c => desktop.FindFirstChild(cf => cf.ByClassName(c)))
                .SelectMany(root => root?.FindAllDescendants(cf => cf.ByAutomationId("NotifyItemIcon")) ?? [])
                .FirstOrDefault(e => (e.Properties.Name.ValueOrDefault ?? "").Trim() == name && !e.IsOffscreen);
        var tray = desktop.FindFirstChild(cf => cf.ByClassName("Shell_TrayWnd"));
        // Tasma penceresi odak degisince kapanir (pencere acilip tepsiye gizlenirken): birkac kez ac.
        for (var attempt = 1; ; attempt++)
        {
            if (Find() is { } visible) return visible;
            Ui.Retry(() => tray!.FindFirstDescendant(cf => cf.ByAutomationId("SystemTrayIcon").And(cf.ByClassName("SystemTray.NormalButton"))), "gizli simgeler")
                .Patterns.Invoke.Pattern.Invoke();
            try { return Ui.Retry(Find, "tepsi simgesi", 3); }
            catch (TimeoutException) when (attempt < 4) { }
        }
    }

    public void Dispose()
    {
        try { if (!App.HasExited) App.Kill(); } catch { /* kapandi */ }
        App.Dispose();
        Automation.Dispose();
        for (var i = 0; i < 10 && Directory.Exists(DataDir); i++)
        {
            try { Directory.Delete(DataDir, recursive: true); }
            catch (IOException) { Thread.Sleep(200); }
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
            try { if (f() is { } r) return r; } catch (COMException) { }
            Thread.Sleep(100);
        }
        throw new TimeoutException("Bulunamadi: " + what);
    }

    public static void Wait(Func<bool> cond, string what, double seconds = 10)
    {
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try { if (cond()) return; } catch (COMException) { }
            if (sw.Elapsed > TimeSpan.FromSeconds(seconds)) throw new TimeoutException("Beklenen durum olusmadi: " + what);
            Thread.Sleep(100);
        }
    }

    /// <summary>Modal diyalog acan komutlarda UIA Invoke diyalog kapanana kadar bekleyebilir: arka planda cagir.</summary>
    public static void InvokeNoWait(AutomationElement e) => _ = Task.Run(() =>
    {
        try { e.Patterns.Invoke.Pattern.Invoke(); } catch { /* zaman asimi */ }
    });

    public static bool HasText(AutomationElement root, string text) =>
        root.FindAllDescendants().Any(e => (e.Properties.Name.ValueOrDefault ?? "").Contains(text));

    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);

    /// <summary>On plana al (cagiran kilidi tutar); reddedilirse baslik cubuguna gercek tik.</summary>
    public static void Focus(Window w)
    {
        var hwnd = w.Properties.NativeWindowHandle.Value;
        var tries = 0;
        Wait(() =>
        {
            if (GetForegroundWindow() == hwnd) return true;
            if (++tries % 5 == 0)
            {
                var r = w.BoundingRectangle;
                Mouse.Click(new System.Drawing.Point(r.X + r.Width / 2, r.Y + 12));
            }
            else SetForegroundWindow(hwnd);
            Thread.Sleep(150);
            return GetForegroundWindow() == hwnd;
        }, "pencere on planda", 20);
    }

    /// <summary>PrintWindow(PW_RENDERFULLCONTENT) ile pencereyi PNG'ye yazar.</summary>
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

/// <summary>Pano islemleri STA is parcaciginda; mesgul panoya karsi tekrar denenir.</summary>
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
                catch (COMException) when (i < 100) { Thread.Sleep(50); }
                catch (Exception ex) { error = ex; return; }
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        if (error != null) throw error;
    }

    public static string? Text()
    {
        string? text = null;
        Sta(() => text = Clipboard.ContainsText() ? Clipboard.GetText() : null);
        return text;
    }
}

/// <summary>
/// Testler panoya renk kodu yazar: kullanicinin pano icerigi (okunabilir bicimler) once saklanir, sonra geri yazilir.
/// Arada baska bir surec panoya yazdiysa (icerik testin yazdigi degilse) dokunulmaz.
/// ponytail: gecikmeli olusturulan / okunamayan ozel bicimler atlanir.
/// </summary>
public sealed class ClipboardSnapshot : IDisposable
{
    private readonly List<(string Format, object Data)> _items = [];
    internal readonly HashSet<string> Written = [];

    public ClipboardSnapshot() => Pano.Sta(() =>
    {
        if (Clipboard.GetDataObject() is not { } d) return;
        foreach (var f in d.GetFormats(autoConvert: false))
        {
            try { if (d.GetData(f, autoConvert: false) is { } v) _items.Add((f, v)); } catch { }
        }
    });

    public void Dispose() => Pano.Sta(() =>
    {
        var now = Clipboard.ContainsText() ? Clipboard.GetText() : null;
        if (now == null || !Written.Contains(now)) return; // baska surecin icerigini ezme
        if (_items.Count == 0) { Clipboard.Clear(); return; }
        var o = new DataObject();
        foreach (var (f, v) in _items)
        {
            try { o.SetData(f, v); } catch { }
        }
        Clipboard.SetDataObject(o, true);
    });
}

/// <summary>Repo kokundeki .gui.lock: gercek girdi ve ekran kopyalama yalnizca kilit icinde.</summary>
internal static class GuiLock
{
    public static FileStream Acquire()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "launcher.ps1"))) dir = dir.Parent;
        var path = Path.Combine(dir?.FullName ?? Path.GetTempPath(), ".gui.lock");
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException) when (sw.Elapsed < TimeSpan.FromMinutes(5)) { Thread.Sleep(500); }
        }
    }
}
