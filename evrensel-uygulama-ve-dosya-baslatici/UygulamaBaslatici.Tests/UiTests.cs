using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;
using UygulamaBaslatici.Services;
using Xunit;

namespace UygulamaBaslatici.Tests;

/// <summary>
/// FlaUI (UIA3) arayüz testleri: gerçek KomutPaleti.exe geçici veri klasörü ve sahte Başlat Menüsü
/// (KOMUT_PALETI_SCAN_DIR) ile açılır. Başlatılan tek şey sahte kısayolun hedefi olan, işaret dosyası yazan cmd'dir.
/// Yalnızca run.ps1 -UiTest ile çalışır (Category=UI).
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IDisposable
{
    private readonly TempDir _tmp = new();
    private readonly UIA3Automation _automation = new();
    private readonly string _dataDir, _scanDir, _marker;
    private Process? _app;

    public UiTests()
    {
        _dataDir = Directory.CreateDirectory(_tmp.Combine("data")).FullName;
        _scanDir = Directory.CreateDirectory(_tmp.Combine("Programs")).FullName;
        _marker = _tmp.Combine("launched.txt");
        Shortcut("Demo Not Defteri", "cmd.exe", $"/c echo ok>> \"{_marker}\"");
        Shortcut("Demo Hesap", "cmd.exe", "/c exit");
        Shortcut("Demo Uninstall", "cmd.exe", "/c exit"); // tarayıcı kaldırma kısayollarını atlar
    }

    public void Dispose()
    {
        if (_app is { HasExited: false }) { _app.Kill(entireProcessTree: true); _app.WaitForExit(5000); }
        _app?.Dispose();
        _automation.Dispose();
        _tmp.Dispose();
    }

    // ---- yardımcılar ----

    private void Shortcut(string name, string target, string args, string? icon = null) =>
        CreateShortcut(Path.Combine(_scanDir, name + ".lnk"), target, args, icon);

    internal static void CreateShortcut(string lnk, string target, string args, string? icon = null)
    {
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")!)!;
        dynamic sc = shell.CreateShortcut(lnk);
        sc.TargetPath = target;
        sc.Arguments = args;
        sc.WindowStyle = 7; // simge durumunda: test sırasında konsol öne çıkmaz
        if (icon != null) sc.IconLocation = icon;
        sc.Save();
    }

    private ProcessStartInfo Psi()
    {
        var psi = new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory, "KomutPaleti.exe")) { UseShellExecute = false };
        psi.Environment[DatabaseService.DataDirEnvVar] = _dataDir;
        psi.Environment[AppScannerService.ScanDirEnvVar] = _scanDir;
        return psi;
    }

    private Window? Palette() =>
        _automation.GetDesktop().FindFirstChild(cf => cf.ByProcessId(_app!.Id))?.AsWindow() is { IsOffscreen: false } w ? w : null;

    /// <summary>
    /// Uygulamayı (gerekirse) başlatır; exe ikinci kez çalıştırılarak palet gösterilir. Palet odak kaybında gizlendiği
    /// için (masaüstünü paylaşan diğer pencereler) adımlar penceriyi her seferinde W ile yeniden alır.
    /// </summary>
    private Window Show()
    {
        var fresh = _app == null;
        _app ??= Process.Start(Psi())!;
        var sw = Stopwatch.StartNew();
        var signalled = false;
        while (sw.Elapsed < TimeSpan.FromSeconds(20))
        {
            if (Palette() is { } w) return w;
            if (!signalled && (!fresh || sw.Elapsed > TimeSpan.FromSeconds(2)))
            {
                using var second = Process.Start(Psi())!;
                Assert.True(second.WaitForExit(10000), "ikinci örnek kapanmalı");
                signalled = true;
            }
            Thread.Sleep(100);
        }
        throw new TimeoutException("Palet gösterilmedi");
    }

    private Window W => Palette() ?? Show();

    private static AutomationElement ById(Window w, string id) =>
        Retry(() => w.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private static bool Visible(Window w, string id) => w.FindFirstDescendant(cf => cf.ByAutomationId(id)) is { IsOffscreen: false };

    private static string[] Items(Window w) =>
        w.FindFirstDescendant(cf => cf.ByAutomationId("ResultsList")) is { IsOffscreen: false } list
            ? list.FindAllDescendants(cf => cf.ByControlType(ControlType.ListItem)).Select(i => i.Name).ToArray()
            : [];

    private static T Retry<T>(Func<T?> f, string what) where T : class
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(10))
        {
            if (f() is { } r) return r;
            Thread.Sleep(100);
        }
        throw new TimeoutException("Bulunamadı: " + what);
    }

    private static void Wait(Func<bool> cond, string what, Func<string>? state = null)
    {
        var sw = Stopwatch.StartNew();
        while (!cond())
        {
            if (sw.Elapsed > TimeSpan.FromSeconds(10)) throw new TimeoutException("Beklenen durum oluşmadı: " + what + " " + state?.Invoke());
            Thread.Sleep(100);
        }
    }

    private static void Search(Window w, string text) => ById(w, "SearchBox").AsTextBox().Text = text;

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    // ---- testler ----

    [Fact]
    public void Search_modes_empty_state_and_rescan()
    {
        Assert.Equal("Komut Paleti", Show().Title);
        // Bos sorgu: en cok kullanilanlar; kaldirma (uninstall) kisayolu indekslenmez.
        Wait(() => Items(W).OrderBy(x => x).SequenceEqual(["Demo Hesap", "Demo Not Defteri"]), "taranan kısayollar",
            () => string.Join("|", Items(W)));
        Assert.Equal("2 sonuç", ById(W, "ResultCountText").Name);

        // Uygulama aramasi + Google satiri
        Search(W, "not def");
        Wait(() => Items(W).SequenceEqual(["Demo Not Defteri", "Google'da ara: \"not def\""]), "uygulama + web");

        // Yerel eslesme yok: bos durum + web dugmeleri (tiklanmaz: tarayici acar)
        Search(W, "zzz-yok");
        Wait(() => Visible(W, "EmptyText") && Visible(W, "GoogleButton") && Visible(W, "WebSearchPill"), "boş durum");
        Assert.Contains("zzz-yok", ById(W, "EmptyText").Name);
        Assert.Empty(Items(W));

        // Komut modu
        Search(W, ">  echo merhaba");
        Wait(() => Items(W).SequenceEqual(["echo merhaba"]), "komut satırı");
        Assert.False(Visible(W, "EmptyText"));

        // Dosya/klasor yolu
        Search(W, _scanDir);
        Wait(() => Items(W).FirstOrDefault() == "Programs", "klasör yolu");

        // Yeniden tara: yeni kisayol eklenir, silinen duser
        Shortcut("Demo Yeni Arac", "cmd.exe", "/c exit");
        File.Delete(Path.Combine(_scanDir, "Demo Hesap.lnk"));
        ById(W, "RescanButton").AsButton().Invoke();
        Search(W, "demo");
        Wait(() => Items(W).Where(i => i.StartsWith("Demo")).OrderBy(x => x)
            .SequenceEqual(["Demo Not Defteri", "Demo Yeni Arac"]), "yeniden tarama", () => string.Join("|", Items(W)));
        Assert.False(File.Exists(_marker), "hiçbir şey başlatılmamalı");
    }

    [Fact]
    public void Keyboard_navigation_launch_and_hide()
    {
        var w = Show();
        Wait(() => Items(w).Length == 2, "kısayollar");
        // Gerçek klavye girdisi: ortak masaüstü kilidi içinde, pencere öndeyken.
        using (GuiLock.Acquire())
        {
            w.SetForeground();
            Wait(() => GetForegroundWindow() == w.Properties.NativeWindowHandle.Value, "palet ön planda");
            Keyboard.Type("not defteri");
            Wait(() => Items(w).FirstOrDefault() == "Demo Not Defteri", "yazarak arama", () => $"shown={Palette() != null} text={ById(W, "SearchBox").AsTextBox().Text} items={string.Join("|", Items(W))} fg={GetForegroundWindow() == w.Properties.NativeWindowHandle.Value}");
            Keyboard.Type(VirtualKeyShort.DOWN);
            Keyboard.Type(VirtualKeyShort.UP); // ilk satıra dön
            Keyboard.Type(VirtualKeyShort.RETURN);
            Wait(() => File.Exists(_marker), "Enter sahte kısayolu başlattı");
            Wait(() => Palette() is null, "başlatınca palet gizlenir");
        }
        Thread.Sleep(1500);
        Assert.Equal(["ok"], File.ReadAllLines(_marker).Select(l => l.Trim()));
        Assert.Equal(1, new DatabaseService(_dataDir).SearchApps("not defteri").Single().UsageCount);

        w = Show();
        using (GuiLock.Acquire())
        {
            w.SetForeground();
            Wait(() => GetForegroundWindow() == w.Properties.NativeWindowHandle.Value, "palet ön planda");
            Wait(() => ById(w, "SearchBox").AsTextBox().Text == "", "başlatma sonrası sorgu temiz");
            Assert.Equal("Demo Not Defteri", Items(w).First()); // en çok kullanılan üstte
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Wait(() => Palette() is null, "Esc gizler");
        }
        Assert.False(_app!.HasExited, "Esc uygulamayı kapatmaz");
    }

    /// <summary>README görüntüsü: yalnızca KOMUT_PALETI_SHOT=docs\ekran.png verilince çalışır (demo verisiyle).</summary>
    [Fact]
    public void Readme_screenshot()
    {
        var output = Environment.GetEnvironmentVariable("KOMUT_PALETI_SHOT");
        if (string.IsNullOrEmpty(output)) return;

        foreach (var f in Directory.GetFiles(_scanDir)) File.Delete(f);
        var sys = Environment.GetFolderPath(Environment.SpecialFolder.System);
        var demo = new (string Name, string Icon, int Uses)[]
        {
            ("Not Defteri", "notepad.exe", 14), ("Hesap Makinesi", "calc.exe", 9), ("Paint", "mspaint.exe", 6),
            ("Görev Yöneticisi", "taskmgr.exe", 4), ("Komut İstemi", "cmd.exe", 2),
        };
        // Görünen yol Başlat Menüsü'ne benzesin, kullanıcı adı içermesin.
        var demoDir = Directory.CreateDirectory(@"C:\ProgramData\KomutPaletiDemo\Start Menu\Programs").FullName;
        try
        {
            var db = new DatabaseService(_dataDir);
            var data = demo.Select(d => new AppScannerData { Name = d.Name, Path = Path.Combine(demoDir, d.Name + ".lnk"), Type = "App" }).ToList();
            foreach (var d in data) CreateShortcut(d.Path, "cmd.exe", "/c exit", Path.Combine(sys, demo.First(x => x.Name == d.Name).Icon) + ",0");
            db.BulkInsertApps(data);
            foreach (var d in demo) for (var i = 0; i < d.Uses; i++) db.IncrementUsage(Path.Combine(demoDir, d.Name + ".lnk"));

            _app = Process.Start(PsiWith(demoDir))!;
            var w = Show();
            Wait(() => Items(w).Length == 5, "demo öğeleri");
            Thread.Sleep(500);
            using (GuiLock.Acquire())
            {
                w.SetForeground();
                Thread.Sleep(400);
                var r = w.BoundingRectangle;
                using var shot = new Bitmap(r.Width, r.Height);
                using (var g = Graphics.FromImage(shot)) g.CopyFromScreen(r.Left, r.Top, 0, 0, shot.Size);
                SaveOnBackdrop(shot, output);
            }
        }
        finally
        {
            try { Directory.Delete(@"C:\ProgramData\KomutPaletiDemo", true); } catch (IOException) { }
        }
    }

    private ProcessStartInfo PsiWith(string scanDir)
    {
        var psi = Psi();
        psi.Environment[AppScannerService.ScanDirEnvVar] = scanDir;
        return psi;
    }

    /// <summary>Paleti 1280x800 koyu arka plana yuvarlak köşelerle yerleştirir (arkadaki masaüstü görünmez).</summary>
    private static void SaveOnBackdrop(Bitmap palette, string output)
    {
        const int W = 1280, H = 800;
        var scale = Math.Min(1.0, Math.Min((W - 160.0) / palette.Width, (H - 160.0) / palette.Height));
        int pw = (int)(palette.Width * scale), ph = (int)(palette.Height * scale);
        int x = (W - pw) / 2, y = Math.Max(80, (H - ph) / 3);
        using var canvas = new Bitmap(W, H);
        using var g = Graphics.FromImage(canvas);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        using (var bg = new LinearGradientBrush(new Rectangle(0, 0, W, H), Color.FromArgb(30, 27, 75), Color.FromArgb(12, 12, 16), 60f))
            g.FillRectangle(bg, 0, 0, W, H);
        var radius = (int)(14 * palette.Width / 640.0 * scale) * 2;
        using var clip = new GraphicsPath();
        clip.AddArc(x, y, radius, radius, 180, 90);
        clip.AddArc(x + pw - radius, y, radius, radius, 270, 90);
        clip.AddArc(x + pw - radius, y + ph - radius, radius, radius, 0, 90);
        clip.AddArc(x, y + ph - radius, radius, radius, 90, 90);
        clip.CloseFigure();
        g.SetClip(clip);
        g.DrawImage(palette, x, y, pw, ph);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
        canvas.Save(output, System.Drawing.Imaging.ImageFormat.Png);
    }
}

/// <summary>Repo kökündeki .gui.lock: ajanlar masaüstünü paylaşır; gerçek girdi/ekran kopyası yalnızca kilit içinde.</summary>
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
