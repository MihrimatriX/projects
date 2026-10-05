using System.IO;
using System.Diagnostics;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;
using ProjeLauncher.Services;
using Xunit;

namespace ProjeLauncher.Tests;

/// <summary>
/// FlaUI (UIA3) arayuz testleri: sahte repo kokunde gercek DevProjects.exe acilir.
/// Gercek projeler asla baslatilmaz (sahte launcher.ps1 yalnizca launched.txt yazar).
/// Yalnizca run.ps1 -UiTest ile calisir (Category=UI; -Check bunlari atlar).
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IDisposable
{
    private readonly FakeRepo _repo = new();
    private readonly UIA3Automation _automation = new();
    private readonly Application _app;
    private readonly Window _window;

    public UiTests()
    {
        var exe = Path.Combine(AppContext.BaseDirectory, "DevProjects.exe");
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false, WorkingDirectory = _repo.Root };
        psi.Environment["DEVPROJECTS_ROOT"] = _repo.Root;
        psi.Environment["DEVPROJECTS_STATE_DIR"] = _repo.StateDir;
        _app = Application.Launch(psi);
        _window = _app.GetMainWindow(_automation, TimeSpan.FromSeconds(20))
                  ?? throw new InvalidOperationException("Ana pencere acilmadi");
        Wait(() => Cards().Length == 5, "5 kart yuklenmeli");
    }

    public void Dispose()
    {
        _app.Close();
        if (!_app.HasExited) _app.Kill();
        _app.Dispose();
        _automation.Dispose();
        _repo.Dispose();
    }

    private AutomationElement ById(string id) =>
        Retry(() => _window.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private AutomationElement ByName(string name) =>
        Retry(() => _window.FindFirstDescendant(cf => cf.ByName(name)), name);

    private bool Exists(string id) => _window.FindFirstDescendant(cf => cf.ByAutomationId(id)) is { IsOffscreen: false };

    private ListBoxItem[] Cards() =>
        _window.FindFirstDescendant(cf => cf.ByAutomationId("ProjectGrid"))?.AsListBox().Items ?? [];

    private static T Retry<T>(Func<T?> f, string what) where T : class
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(10))
        {
            if (f() is { } r) return r;
            Thread.Sleep(100);
        }
        throw new TimeoutException("Bulunamadi: " + what);
    }

    private static void Wait(Func<bool> cond, string what)
    {
        var sw = Stopwatch.StartNew();
        while (!cond())
        {
            if (sw.Elapsed > TimeSpan.FromSeconds(10)) throw new TimeoutException("Beklenen durum olusmadi: " + what);
            Thread.Sleep(100);
        }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    private void Search(string text) => ById("SearchBox").AsTextBox().Text = text;

    [Fact]
    public void Search_filter_selection_detail_and_launch()
    {
        // Arama: Turkce harf duyarsiz; sonuc metni ve bos durum.
        Search("ISTANBUL");
        Wait(() => Cards().Length == 1, "arama 1 sonuc");
        Assert.Equal("İstanbul Öğrenme Aracı", Cards()[0].Name);
        Assert.Equal("1 / 5 proje", ById("ResultText").Name);
        Search("zzz-yok");
        Wait(() => Cards().Length == 0 && Exists("EmptyState"), "bos durum");
        Search("");
        Wait(() => Cards().Length == 5, "arama temizlendi");

        // Kenar cubugu: yigin ve kategori; exe filtresi.
        var nav = ById("NavList").AsListBox();
        nav.Items.Single(i => i.Name == "Flutter").Select();
        Wait(() => Cards().Length == 1 && Cards()[0].Name == "Beta Takvim", "Flutter filtresi");
        nav.Items.Single(i => i.Name == "Verimlilik").Select();
        Wait(() => Cards().Length == 2, "kategori filtresi");
        nav.Items.Single(i => i.Name == "Tüm projeler").Select();
        ById("ExeHas").AsRadioButton().IsChecked = true;
        Wait(() => Cards().Length == 1, "exe var");
        ById("ExeNo").AsRadioButton().IsChecked = true;
        Wait(() => Cards().Length == 4, "exe yok");
        ById("ExeAll").AsRadioButton().IsChecked = true;
        Wait(() => Cards().Length == 5, "exe hepsi");

        // Secim + detay
        var alpha = Cards().Single(c => c.Name == "İstanbul Öğrenme Aracı");
        alpha.Select();
        Assert.True(alpha.IsSelected);
        ByName("Ayrıntılar: İstanbul Öğrenme Aracı").AsButton().Invoke();
        Wait(() => Exists("DetailTitle"), "detay acildi");
        Assert.Equal("İstanbul Öğrenme Aracı", ById("DetailTitle").Name);
        Assert.False(Exists("ProjectGrid"));
        Assert.Equal(2, ById("ShotList").AsListBox().Items.Length);
        Assert.Contains(ById("TagList").FindAllDescendants(), e => e.Name == "regex");
        Assert.True(ById("PublishButton").IsEnabled);

        // Eylem: Kaynaktan calistir -> sahte launcher.ps1 -Exec alpha-dotnet
        ById("SourceButton").AsButton().Invoke();
        Wait(() => File.Exists(_repo.LaunchedFile), "launcher.ps1 calisti");
        Wait(() => File.ReadAllText(_repo.LaunchedFile).Contains("Exec=alpha-dotnet"), "dogru proje");
        Assert.Contains("Kaynaktan başlatıldı", ById("StatusText").Name);

        // Favori + kalicilik
        ById("FavoriteButton").AsButton().Invoke();
        Wait(() => File.Exists(Path.Combine(_repo.StateDir, "state.json")), "state.json yazildi");
        var state = new StateStore(_repo.StateDir).Load();
        Assert.Equal(["alpha-dotnet"], state.Favorites);
        Assert.Equal(["alpha-dotnet"], state.Recent);

        // Geri: galeri, son kullanilanlar listesi
        ById("BackButton").AsButton().Invoke();
        Wait(() => Exists("ProjectGrid"), "galeriye donus");
        nav.Items.Single(i => i.Name == "Son kullanılanlar").Select();
        Wait(() => Cards().Length == 1, "son kullanilanlar");
        nav.Items.Single(i => i.Name == "Favoriler").Select();
        Wait(() => Cards().Length == 1, "favoriler");

        // Durum cubugu: arac zinciri denetimi tamamlanir.
        Wait(() => ById("Toolchains").FindAllChildren().Length == 4, "arac zinciri");
    }

    [Fact]
    public void Keyboard_shortcuts()
    {
        // Gercek klavye girdisi: ortak masaustu kilidi icinde.
        using var gui = GuiLock.Acquire();
        // Pencere on planda degilse tuslar baska uygulamaya gider: o durumda yazmadan dur.
        _window.SetForeground();
        Wait(() => GetForegroundWindow() == _window.Properties.NativeWindowHandle.Value, "pencere on planda");
        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_F);
        Keyboard.Type("beta");
        Wait(() => Cards().Length == 1, "Ctrl+F ile arama");
        Keyboard.Type(VirtualKeyShort.ESCAPE);
        Wait(() => Cards().Length == 5, "Esc aramayi temizler");

        Keyboard.Type("ışık");
        Wait(() => Cards().Length == 1, "Turkce klavye girdisi");
        Keyboard.Type(VirtualKeyShort.DOWN); // aramadan karta
        Wait(() => Cards()[0].IsSelected, "ok tusu karti secer");
        Keyboard.Type(VirtualKeyShort.RETURN);
        Wait(() => Exists("DetailTitle"), "Enter detay acar");
        Keyboard.Type(VirtualKeyShort.ESCAPE);
        Wait(() => Exists("ProjectGrid"), "Esc detayi kapatir");
        Keyboard.Type(VirtualKeyShort.ESCAPE);
        Wait(() => Cards().Length == 5, "Esc aramayi temizler");
        Keyboard.Type(VirtualKeyShort.F5);
        Wait(() => ById("StatusText").Name.Contains("5 proje"), "F5 yeniler");
    }
}

/// <summary>Repo kokundeki .gui.lock: 5 agent masaustunu paylasir; gercek girdi yalnizca kilit icinde.</summary>
internal static class GuiLock
{
    public static FileStream Acquire()
    {
        var path = Path.Combine(RepoRoot.Find(), ".gui.lock");
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException) when (sw.Elapsed < TimeSpan.FromMinutes(5)) { Thread.Sleep(500); }
        }
    }
}
