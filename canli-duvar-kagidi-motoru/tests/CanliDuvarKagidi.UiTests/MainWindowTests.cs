using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text.Json;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.Tools;
using FlaUI.Core.WindowsAPI;
using Microsoft.Win32;

namespace CanliDuvarKagidi.UiTests;

public sealed class MainWindowTests(AppFixture fx)
{
    private const string GorselTitle = "Örnek Statik Görsel";

    private AutomationElement LibraryItem(string titlePrefix) =>
        Retry.WhileNull(() => fx.GridItems("InstalledGrid").FirstOrDefault(i => i.Name.StartsWith(titlePrefix, StringComparison.Ordinal)),
            AppFixture.Wait, throwOnTimeout: true, timeoutMessage: $"Kutuphanede yok: {titlePrefix}").Result!;

    private void SetSearch(string text)
    {
        fx.Find("SearchBox").Patterns.Value.Pattern.SetValue(text);
    }

    [Fact]
    public void Library_lists_bundled_samples_with_readable_names_and_search_filters()
    {
        fx.Navigate("installed", "Kütüphanem");
        SetSearch("");
        var items = Retry.WhileEmpty(() => fx.GridItems("InstalledGrid"), AppFixture.Wait).Result!;

        Assert.Equal(items.Length.ToString(), fx.Text("InstalledCount"));
        Assert.Contains(items, i => i.Name == $"{GorselTitle}, Görsel"); // ekran okuyucu sinif adi degil baslik okur

        SetSearch("web");
        Retry.WhileFalse(() => fx.GridItems("InstalledGrid").All(i => i.Name.Contains("Web")), AppFixture.Wait, throwOnTimeout: true);
        Assert.NotEmpty(fx.GridItems("InstalledGrid"));

        SetSearch("gorsel"); // Turkce karaktersiz arama da bulur
        Assert.NotNull(LibraryItem(GorselTitle));

        SetSearch("bu-isimde-bir-sey-yok");
        Retry.WhileFalse(() => fx.Text("InstalledEmptyTitle") == "Eşleşen duvar kağıdı yok", AppFixture.Wait, throwOnTimeout: true);
        // Filtre bos sonuc verince "Magazaya git" gizlenir (kutuphane bos degil)
        Assert.Null(fx.Window.FindFirstDescendant(cf => cf.ByAutomationId("GoToCatalogButton")));

        SetSearch("");
        Retry.WhileFalse(() => fx.GridItems("InstalledGrid").Length.ToString() == fx.Text("InstalledCount"), AppFixture.Wait, throwOnTimeout: true);
    }

    [Fact]
    public void Apply_without_selection_warns_then_apply_pause_and_remove_on_monitors_page()
    {
        fx.Navigate("installed", "Kütüphanem");
        SetSearch("");
        foreach (var item in fx.GridItems("InstalledGrid").Where(i => i.Patterns.SelectionItem.Pattern.IsSelected.Value))
        {
            try { item.Patterns.SelectionItem.Pattern.RemoveFromSelection(); }
            catch (Exception) { /* tekli secimde kaldirma desteklenmeyebilir */ }
        }

        if (!fx.GridItems("InstalledGrid").Any(i => i.Patterns.SelectionItem.Pattern.IsSelected.Value))
        {
            fx.Find("ApplyInstalledButton").AsButton().Invoke();
            fx.WaitInfo("InstalledInfoBar", "Lütfen bir duvar kağıdı seçin.");
        }

        LibraryItem(GorselTitle).Patterns.SelectionItem.Pattern.Select();
        fx.Find("ApplyInstalledButton").AsButton().Invoke();
        fx.WaitInfo("InstalledInfoBar", $"\"{GorselTitle}\" birincil monitöre uygulandı.");

        // Ayar kalici: test veri klasorundeki settings.json'a yazildi (gercek masaustune dokunulmadi)
        var settings = JsonDocument.Parse(File.ReadAllText(Path.Combine(fx.DataDir, "settings.json")));
        Assert.Contains(settings.RootElement.GetProperty("MonitorWallpapers").EnumerateObject(), p => p.Value.GetString() == "ornek-gorsel");

        fx.Navigate("monitors", "Monitörler");
        var cardText = () => AppFixture.AllText(fx.Find("MonitorRepeater"));
        Retry.WhileFalse(() => cardText().Contains($"Duvar kağıdı: {GorselTitle}"), AppFixture.Wait, throwOnTimeout: true);

        var pause = fx.Find("PauseAllSwitch").Patterns.Toggle.Pattern;
        Assert.Equal(ToggleState.Off, pause.ToggleState.Value);
        pause.Toggle();
        Retry.WhileFalse(() => cardText().Contains("(duraklatıldı)"), AppFixture.Wait, throwOnTimeout: true);
        pause.Toggle();
        Retry.WhileTrue(() => cardText().Contains("(duraklatıldı)"), AppFixture.Wait, throwOnTimeout: true);

        fx.Find("RemoveMonitorButton").AsButton().Invoke();
        fx.WaitInfo("MonitorInfoBar", "için duvar kağıdı kaldırıldı.");
        Retry.WhileFalse(() => cardText().Contains("Duvar kağıdı: Atanmadı"), AppFixture.Wait, throwOnTimeout: true);

        // Ikinci kez kaldir: atanmis yok mesaji; secim sifirlanmamis olmali (eskiden "Monitör seçin." diyordu)
        fx.Find("RemoveMonitorButton").AsButton().Invoke();
        fx.WaitInfo("MonitorInfoBar", "atanmış duvar kağıdı yok");
    }

    [Fact]
    public void Monitors_page_assigns_with_pickers_and_keeps_selection()
    {
        fx.Navigate("monitors", "Monitörler");
        var wallpapers = fx.Find("WallpaperPicker").AsComboBox();
        var index = Array.FindIndex(wallpapers.Items, i => i.Text == GorselTitle);
        Assert.True(index >= 0, "Duvar kagidi seciminde ornek gorsel yok: " + string.Join(", ", wallpapers.Items.Select(i => i.Text)));
        wallpapers.Select(index);
        wallpapers.Collapse();

        fx.Find("ApplyMonitorButton").AsButton().Invoke();
        fx.WaitInfo("MonitorInfoBar", $"\"{GorselTitle}\" →");

        // Uygulama sonrasi liste yenilenince secimler korunur; Kaldir dogrudan calisir
        fx.Find("RemoveMonitorButton").AsButton().Invoke();
        fx.WaitInfo("MonitorInfoBar", "için duvar kağıdı kaldırıldı.");
    }

    [Fact]
    public void Store_loads_catalog_on_first_visit_and_installs_selected_item()
    {
        fx.Navigate("catalog", "Mağaza");
        fx.WaitInfo("CatalogInfoBar", "duvar kağıdı yüklendi.");
        var items = Retry.WhileEmpty(() => fx.GridItems("CatalogGrid"), AppFixture.Wait).Result!;
        Assert.Contains(items, i => i.Name.StartsWith(GorselTitle + ", Görsel, v1.0.0 · Kurulu", StringComparison.Ordinal));

        fx.Find("DownloadButton").AsButton().Invoke();
        fx.WaitInfo("CatalogInfoBar", "Lütfen katalogdan bir duvar kağıdı seçin.");

        items.First(i => i.Name.StartsWith("Örnek Web", StringComparison.Ordinal)).Patterns.SelectionItem.Pattern.Select();
        fx.Find("DownloadButton").AsButton().Invoke();
        fx.WaitInfo("CatalogInfoBar", "\"Örnek Web Animasyonu\" kuruldu.");
    }

    [Fact]
    public void Import_via_file_dialog_then_uninstall_asks_for_confirmation()
    {
        fx.Navigate("installed", "Kütüphanem");
        SetSearch("");
        var png = Path.Combine(fx.DataDir, "Test Deniz Manzarası.png");
        using (var bmp = new Bitmap(32, 18))
            bmp.Save(png, ImageFormat.Png);

        // Secici modal bir dongu calistirabilir; Invoke'u arka planda tetikle
        var import = fx.Find("ImportButton").AsButton();
        _ = Task.Run(() => import.Invoke());
        var dialog = Retry.WhileNull(() =>
                fx.Window.FindFirstDescendant(cf => cf.ByClassName("#32770")) ??
                fx.Automation.GetDesktop().FindFirstChild(cf => cf.ByClassName("#32770").And(cf.ByProcessId(fx.App.ProcessId))),
            AppFixture.Wait, throwOnTimeout: true, timeoutMessage: "Dosya secme penceresi acilmadi").Result!;
        var nameBox = Retry.WhileNull(() => dialog.FindFirstDescendant(cf => cf.ByAutomationId("1148").And(cf.ByControlType(ControlType.Edit))),
            AppFixture.Wait, throwOnTimeout: true).Result!;
        nameBox.Patterns.Value.Pattern.SetValue(png);
        dialog.FindFirstDescendant(cf => cf.ByAutomationId("1").And(cf.ByControlType(ControlType.Button))).AsButton().Invoke();

        fx.WaitInfo("InstalledInfoBar", "1 duvar kağıdı eklendi: Test Deniz Manzarası");
        var item = LibraryItem("Test Deniz Manzarası");

        // Vazgec: silinmez
        item.Patterns.SelectionItem.Pattern.Select();
        fx.Find("UninstallButton").AsButton().Invoke();
        fx.Find("CloseButton").AsButton().Invoke();
        Thread.Sleep(500);
        Assert.NotNull(LibraryItem("Test Deniz Manzarası"));

        // Onayla: silinir
        LibraryItem("Test Deniz Manzarası").Patterns.SelectionItem.Pattern.Select();
        fx.Find("UninstallButton").AsButton().Invoke();
        fx.Find("PrimaryButton").AsButton().Invoke();
        fx.WaitInfo("InstalledInfoBar", "\"Test Deniz Manzarası\" kaldırıldı.");
        Assert.DoesNotContain(fx.GridItems("InstalledGrid"), i => i.Name.StartsWith("Test Deniz", StringComparison.Ordinal));
        Assert.Empty(Directory.GetDirectories(Path.Combine(fx.DataDir, "installed"), "yerel-test-deniz*"));
    }

    [Fact]
    public void Settings_validate_url_save_and_do_not_touch_registry_in_test_mode()
    {
        fx.Navigate("settings", "Ayarlar");
        using var run = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        var before = run?.GetValue("CanliDuvarKagidi");

        var url = fx.Find("CatalogUrlBox").Patterns.Value.Pattern;
        Assert.Equal("bundled", url.Value.Value);
        url.SetValue("ftp://gecersiz");
        fx.Find("SaveSettingsButton").AsButton().Invoke();
        fx.WaitInfo("SettingsInfoBar", "Katalog URL geçersiz.");

        url.SetValue("bundled");
        var fullscreen = fx.Find("PauseFullscreenSwitch").Patterns.Toggle.Pattern;
        Assert.Equal(ToggleState.On, fullscreen.ToggleState.Value);
        fullscreen.Toggle();
        var startup = fx.Find("RunAtStartupSwitch").Patterns.Toggle.Pattern;
        startup.Toggle();
        fx.Find("SaveSettingsButton").AsButton().Invoke();
        fx.WaitInfo("SettingsInfoBar", "Ayarlar kaydedildi.");

        var saved = JsonDocument.Parse(File.ReadAllText(Path.Combine(fx.DataDir, "settings.json"))).RootElement;
        Assert.False(saved.GetProperty("PauseOnFullscreen").GetBoolean());
        Assert.True(saved.GetProperty("RunAtStartup").GetBoolean());
        using (var after = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
            Assert.Equal(before, after?.GetValue("CanliDuvarKagidi"));

        // Geri al
        fullscreen.Toggle();
        startup.Toggle();
        fx.Find("SaveSettingsButton").AsButton().Invoke();

        fx.Find("ClearCacheButton").AsButton().Invoke();
        fx.WaitInfo("SettingsInfoBar", "Önbellek temizlendi.");
    }

    [Fact]
    public void Keyboard_shortcuts_navigate_search_and_pause()
    {
        using var _ = GuiLock.Acquire(fx.RepoRoot);
        fx.Window.SetForeground();
        fx.Window.Focus();
        Thread.Sleep(300);

        void Ctrl(VirtualKeyShort key)
        {
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, key);
            Thread.Sleep(250);
        }

        Ctrl(VirtualKeyShort.KEY_2);
        Retry.WhileFalse(() => fx.Text("PageTitle") == "Mağaza", AppFixture.Wait, throwOnTimeout: true);
        Ctrl(VirtualKeyShort.KEY_3);
        Retry.WhileFalse(() => fx.Text("PageTitle") == "Monitörler", AppFixture.Wait, throwOnTimeout: true);

        var pause = fx.Find("PauseAllSwitch").Patterns.Toggle.Pattern;
        var initial = pause.ToggleState.Value;
        Ctrl(VirtualKeyShort.KEY_P);
        Retry.WhileFalse(() => pause.ToggleState.Value != initial, AppFixture.Wait, throwOnTimeout: true);
        Ctrl(VirtualKeyShort.KEY_P);
        Retry.WhileFalse(() => pause.ToggleState.Value == initial, AppFixture.Wait, throwOnTimeout: true);

        Ctrl(VirtualKeyShort.KEY_4);
        Retry.WhileFalse(() => fx.Text("PageTitle") == "Ayarlar", AppFixture.Wait, throwOnTimeout: true);

        Ctrl(VirtualKeyShort.KEY_F);
        Retry.WhileFalse(() => fx.Text("PageTitle") == "Kütüphanem", AppFixture.Wait, throwOnTimeout: true);
        Retry.WhileFalse(() => fx.Find("SearchBox").Properties.HasKeyboardFocus.ValueOrDefault, AppFixture.Wait, throwOnTimeout: true);
        Keyboard.Type("web");
        Retry.WhileFalse(() => fx.GridItems("InstalledGrid").All(i => i.Name.Contains("Web")), AppFixture.Wait, throwOnTimeout: true);
        SetSearch("");

        // Kart odaktayken Delete onay sorar (Vazgec), Enter uygular
        var card = LibraryItem(GorselTitle);
        card.Patterns.SelectionItem.Pattern.Select();
        card.Focus();
        Keyboard.Type(VirtualKeyShort.DELETE);
        fx.Find("CloseButton").AsButton().Invoke();
        card = LibraryItem(GorselTitle);
        card.Focus();
        Keyboard.Type(VirtualKeyShort.ENTER);
        fx.WaitInfo("InstalledInfoBar", $"\"{GorselTitle}\" birincil monitöre uygulandı.");
    }

    /// <summary>README ekran goruntusu: CDK_EKRAN_DIR ayarliysa ana ekrani PrintWindow ile kaydeder.</summary>
    [Fact]
    public void Screenshot_for_readme()
    {
        var dir = Environment.GetEnvironmentVariable("CDK_EKRAN_DIR");
        Assert.SkipWhen(string.IsNullOrEmpty(dir), "CDK_EKRAN_DIR ayarli degil");

        var hwnd = fx.Window.Properties.NativeWindowHandle.Value;
        SetWindowPos(hwnd, IntPtr.Zero, 80, 60, 1280, 800, 0x0004 | 0x0010); // NOZORDER | NOACTIVATE

        fx.Navigate("installed", "Kütüphanem");
        SetSearch("");
        LibraryItem(GorselTitle).Patterns.SelectionItem.Pattern.Select();
        Capture(hwnd, Path.Combine(dir!, "ekran.png"));

        fx.Navigate("catalog", "Mağaza");
        Retry.WhileEmpty(() => fx.GridItems("CatalogGrid"), AppFixture.Wait);
        Capture(hwnd, Path.Combine(dir!, "ekran-magaza.png"));

        fx.Navigate("monitors", "Monitörler");
        Capture(hwnd, Path.Combine(dir!, "ekran-monitorler.png"));
        fx.Navigate("installed", "Kütüphanem");
    }

    private static void Capture(IntPtr hwnd, string path)
    {
        Thread.Sleep(800); // gecis animasyonlari bitsin
        GetWindowRect(hwnd, out var r);
        using var bmp = new Bitmap(r.Right - r.Left, r.Bottom - r.Top);
        using (var g = Graphics.FromImage(bmp))
        {
            var hdc = g.GetHdc();
            PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT
            g.ReleaseHdc(hdc);
        }
        bmp.Save(path, ImageFormat.Png);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
