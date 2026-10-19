using System.Diagnostics;
using System.IO;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;
using EkranGoruntusu.Services;
using Xunit;

namespace EkranGoruntusu.Tests;

/// <summary>
/// FlaUI (UIA3) arayüz testleri: gerçek EkranGoruntusu.exe geçici veri klasörüyle (EKRAN_GORUNTUSU_DATA_DIR) açılır.
/// Ortak dosya diyalogları ve MessageBox'lar UIA ile sürülür. Ekran kopyası (yakalama) ve gerçek fare/klavye
/// adımları ortak .gui.lock içinde çalışır. Yalnızca run.ps1 -UiTest ile (Category=UI).
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IDisposable
{
    private readonly TempDir _tmp = new();
    private readonly UIA3Automation _automation = new();
    private readonly Application _app;
    private readonly Window _window;

    public UiTests()
    {
        var psi = new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory, "EkranGoruntusu.exe"))
        {
            UseShellExecute = false,
            WorkingDirectory = _tmp.Path
        };
        psi.Environment[SettingsService.DataDirEnvVar] = _tmp.Combine("veri");
        _app = Application.Launch(psi);
        _window = _app.GetMainWindow(_automation, TimeSpan.FromSeconds(20)) ?? throw new InvalidOperationException("Ana pencere açılmadı");
        ById(_window, "CaptureButton");
    }

    public void Dispose()
    {
        try { _app.Kill(); } catch (Exception) { }
        _app.Dispose();
        _automation.Dispose();
        Thread.Sleep(300);
        _tmp.Dispose();
    }

    // --- yardımcılar ---

    private static T Retry<T>(Func<T?> f, string what, int seconds = 15) where T : class
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(seconds))
        {
            try { if (f() is { } r) return r; } catch (Exception) { }
            Thread.Sleep(100);
        }
        throw new TimeoutException("Bulunamadı: " + what);
    }

    private static void Wait(Func<bool> cond, string what, int seconds = 15)
    {
        var sw = Stopwatch.StartNew();
        while (true)
        {
            try { if (cond()) return; } catch (Exception) when (sw.Elapsed < TimeSpan.FromSeconds(seconds)) { }
            if (sw.Elapsed > TimeSpan.FromSeconds(seconds)) throw new TimeoutException("Beklenen durum oluşmadı: " + what);
            Thread.Sleep(100);
        }
    }

    private static AutomationElement ById(AutomationElement root, string id) =>
        Retry(() => root.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private static bool Visible(AutomationElement root, string id) =>
        root.FindFirstDescendant(cf => cf.ByAutomationId(id)) is { IsOffscreen: false };

    private static string Text(AutomationElement root, string id) =>
        root.FindFirstDescendant(cf => cf.ByAutomationId(id))?.Name ?? string.Empty;

    private static void Click(AutomationElement root, string id) => ById(root, id).AsButton().Invoke();

    private static void ClickName(AutomationElement root, string name) =>
        Retry(() => root.FindFirstDescendant(cf => cf.ByName(name).And(cf.ByControlType(ControlType.Button))), name).AsButton().Invoke();

    // Sahipli pencereler (Ayarlar) UIA'da ana pencerenin çocuğu olarak görünür.
    private Window? FindWindow(string title) =>
        _app.GetAllTopLevelWindows(_automation).FirstOrDefault(w => w.Title == title)
        ?? _window.FindFirstChild(cf => cf.ByName(title).And(cf.ByControlType(ControlType.Window)))?.AsWindow();

    private Window TopWindow(string title) => Retry(() => FindWindow(title), "pencere: " + title);

    private bool HasTopWindow(string title) => FindWindow(title) != null;

    private ListBoxItem[] History() =>
        _window.FindFirstDescendant(cf => cf.ByAutomationId("HistoryList"))?.AsListBox().Items ?? [];

    // Kalıcı diyalog: sahibin altında (ModalWindows) ya da Win32 iletişim kutusu sınıfıyla (#32770) bir çocuk pencere.
    private static Window? FindDialog(Window owner) =>
        owner.ModalWindows.FirstOrDefault()
        ?? owner.FindFirstChild(cf => cf.ByClassName("#32770"))?.AsWindow();

    private static Window Dialog(Window owner) => Retry(() => FindDialog(owner), "diyalog");

    private static void WaitNoDialog(Window owner) => Wait(() => FindDialog(owner) == null, "diyalog kapandı");

    /// <summary>MessageBox: Evet=6, Hayır=7, Tamam=2 (tek düğmeli kutuda) — dil bağımsız Win32 kimlikleri.</summary>
    private static string Answer(Window owner, string buttonId)
    {
        var dlg = Dialog(owner);
        var text = string.Join(" ", dlg.FindAllDescendants(cf => cf.ByControlType(ControlType.Text)).Select(t => t.Properties.Name.ValueOrDefault));
        Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId(buttonId)), "düğme " + buttonId).AsButton().Invoke();
        WaitNoDialog(owner);
        return text;
    }

    /// <summary>Aç/klasör diyaloğuna tam yolu yazar; diyalog WM_SETTEXT'i görmezse yalnız bu tuşlar için kilitle klavyeyle yazar.</summary>
    private void CompleteFileDialog(Window owner, string path)
    {
        Assert.StartsWith(_tmp.Path, path);
        var dlg = Dialog(owner);
        var ok = Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("1").And(
            cf.ByControlType(ControlType.Button).Or(cf.ByControlType(ControlType.SplitButton)))), "Aç düğmesi");
        var edit = Retry(() =>
            dlg.FindFirstDescendant(cf => cf.ByAutomationId("1148").And(cf.ByControlType(ControlType.Edit)))
            ?? dlg.FindFirstDescendant(cf => cf.ByAutomationId("1152").And(cf.ByControlType(ControlType.Edit))), "ad kutusu").AsTextBox();
        Wait(() => { edit.Text = path; Thread.Sleep(300); return edit.Text == path; }, "yol yazıldı");
        ok.Patterns.Invoke.Pattern.Invoke();
        try { Wait(() => FindDialog(owner) == null, "diyalog kapandı", 3); return; }
        catch (TimeoutException) { }
        using (GuiLock.Acquire())
        {
            dlg.SetForeground();
            edit.Focus();
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
            Keyboard.Type(path);
            Keyboard.Type(VirtualKeyShort.RETURN);
            WaitNoDialog(owner);
        }
    }

    private static void CancelDialog(Window owner)
    {
        var dlg = Dialog(owner);
        Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("2").And(cf.ByControlType(ControlType.Button))), "İptal").AsButton().Invoke();
        WaitNoDialog(owner);
    }

    private static void Select(AutomationElement root, string name) =>
        Retry(() => root.FindFirstDescendant(cf => cf.ByName(name).And(cf.ByControlType(ControlType.RadioButton))), name)
            .Patterns.SelectionItem.Pattern.Select();

    private static bool IsSelected(AutomationElement root, string name) =>
        root.FindFirstDescendant(cf => cf.ByName(name).And(cf.ByControlType(ControlType.RadioButton)))?
            .Patterns.SelectionItem.Pattern.IsSelected.Value == true;

    private string Shots => _tmp.Combine("veri", "screenshots");

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);

    private static string ForegroundTitle()
    {
        var sb = new System.Text.StringBuilder(256);
        GetWindowText(GetForegroundWindow(), sb, 256);
        return sb.ToString();
    }

    private static void Foreground(Window w)
    {
        // Windows ön plan kilidi ilk denemeyi reddedebilir: tekrar dene.
        Wait(() =>
        {
            if (GetForegroundWindow() == w.Properties.NativeWindowHandle.Value) return true;
            w.SetForeground();
            Thread.Sleep(200);
            if (GetForegroundWindow() != w.Properties.NativeWindowHandle.Value)
            {
                // Ön plan kilidi (ör. kalıcı bildirim açılır penceresi): pencerenin üst kenarına gerçek tıklama (kilit içindeyiz).
                var b = w.BoundingRectangle;
                Mouse.Click(new System.Drawing.Point(b.Left + b.Width / 2, b.Top + 12));
                Thread.Sleep(200);
            }
            return GetForegroundWindow() == w.Properties.NativeWindowHandle.Value;
        }, "pencere ön planda: " + w.Title + " / şu an önde: " + ForegroundTitle(), 40); // bildirim (toast) geçici olarak önü alabilir
    }

    // --- testler ---

    [Fact]
    public void History_editor_ocr_search_edit_delete_settings()
    {
        // Boş durum + kısayol ipucu.
        Assert.Contains("Ctrl + Alt + A", Text(_window, "EmptyHint"));
        Assert.False(ById(_window, "ClearHistoryButton").IsEnabled);

        // Görsel aç (Ctrl+O düğmesi) -> Aç diyaloğu -> düzenleyici.
        var png = _tmp.Combine("fatura.png");
        TestImage.WriteText(png, "MERHABA 2026");
        Click(_window, "OpenImageButton");
        CompleteFileDialog(_window, png);
        var editor = TopWindow("Ekran Görüntüsü Düzenleyici");
        Assert.Equal("900 × 220 · PNG", Text(editor, "MetaLabel"));

        // Araçlar tek seçimli.
        Assert.True(IsSelected(editor, "➚ Ok"));
        foreach (var tool in new[] { "▭ Dikdörtgen", "✎ Kalem", "T Metin", "▦ Gizle", "➚ Ok" })
        {
            Select(editor, tool);
            Wait(() => IsSelected(editor, tool), tool);
        }
        Assert.False(editor.FindFirstDescendant(cf => cf.ByName("Geri al")).IsEnabled);

        // OCR paneli.
        ClickName(editor, "OCR");
        var hasOcr = Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages() != null;
        if (hasOcr)
            Wait(() => editor.FindFirstDescendant(cf => cf.ByName("OCR sonucu").And(cf.ByControlType(ControlType.Edit)))?
                .AsTextBox().Text.Contains("2026") == true, "OCR metni", 30);
        else
            Wait(() => editor.FindFirstDescendant(cf => cf.ByName("Metin bulunamadı")) != null, "OCR boş durumu", 30);

        // Kaydet -> geçmiş + detay paneli (seçili kayıt görünür).
        ClickName(editor, "Kaydet");
        Wait(() => History().Length == 1, "kayıt geçmişte", 30);
        Wait(() => !HasTopWindow("Ekran Görüntüsü Düzenleyici"), "düzenleyici kapandı");
        Wait(() => Visible(_window, "PreviewImage"), "detay paneli görünür");
        Assert.Single(Directory.GetFiles(Shots, "*.png"));
        if (hasOcr) Assert.Contains("2026", ById(_window, "OcrText").AsTextBox().Text);
        Assert.True(ById(_window, "ClearHistoryButton").IsEnabled);

        // Düzenle -> aynı görsel düzenleyicide; değişiklik yokken kapatma onay sormaz.
        Click(_window, "EditButton");
        editor = TopWindow("Ekran Görüntüsü Düzenleyici");
        Assert.Equal("900 × 220 · PNG", Text(editor, "MetaLabel"));
        ClickName(editor, "Kaydet");
        Wait(() => History().Length == 2, "ikinci kayıt", 30);

        // Arama: OCR metni / dosya adı; boş sonuç durumu.
        var search = ById(_window, "SearchBox").AsTextBox();
        search.Text = hasOcr ? "merhaba" : ".png";
        Wait(() => History().Length == 2, "arama eşleşir");
        search.Text = "yok-böyle-bir-şey";
        Wait(() => History().Length == 0 && Visible(_window, "NoMatchText"), "eşleşme yok");
        Click(_window, "ClearSearchButton");
        Wait(() => History().Length == 2, "arama temizlendi");

        // Sil: Hayır -> kalır, Evet -> kayıt ve dosya silinir.
        History()[0].Select();
        Click(_window, "DeleteButton");
        Assert.Contains(".png", Answer(_window, "7"));
        Assert.Equal(2, History().Length);
        Click(_window, "DeleteButton");
        Answer(_window, "6");
        Wait(() => History().Length == 1, "silindi");
        Assert.Single(Directory.GetFiles(Shots, "*.png"));

        // Ayarlar penceresi.
        Click(_window, "SettingsButton");
        var settings = TopWindow("Ayarlar");
        Assert.Equal("Ctrl + Alt + A", ById(settings, "HotkeyBox").AsComboBox().SelectedItem?.Name);
        var template = ById(settings, "TemplateBox").AsTextBox();
        template.Text = "ekran:{HH}";
        Click(settings, "SaveSettingsButton");
        Assert.Contains("Geçersiz", Dialog(settings).Title + Answer(settings, "2"));
        template.Text = "ekran_{HH}{mm}{ss}";
        ById(settings, "HistoryLimitBox").AsComboBox().Select(1); // 50
        ById(settings, "HotkeyBox").AsComboBox().Select(3);      // Ctrl+Shift+S
        Click(settings, "SaveSettingsButton");
        var msg = Answer(settings, "2");
        var json = File.ReadAllText(_tmp.Combine("veri", "settings.json"));
        Assert.Contains("ekran_{HH}{mm}{ss}", json);
        Assert.Contains("\"HistoryLimit\": 50", json);
        if (!msg.Contains("kaydedilemedi")) Assert.Equal("Ctrl+Shift+S", new SettingsService(_tmp.Combine("veri")).Hotkey); // başka uygulama kullanmıyorsa

        // Gözat -> klasör diyaloğu (iptal); Varsayılana dön -> Evet.
        Click(settings, "BrowseButton");
        CancelDialog(settings);
        Click(settings, "ResetButton");
        Answer(settings, "6");
        Wait(() => ById(settings, "TemplateBox").AsTextBox().Text == "{yyyy}-{MM}-{dd}_{HH}{mm}{ss}", "varsayılan şablon");
        Assert.Equal("20", ById(settings, "HistoryLimitBox").AsComboBox().SelectedItem?.Name);
        Click(settings, "SettingsCloseButton");
        Wait(() => !HasTopWindow("Ayarlar"), "ayarlar kapandı");

        // Geçmişi temizle -> Evet: liste ve dosyalar boş.
        Click(_window, "ClearHistoryButton");
        Answer(_window, "6");
        Wait(() => Visible(_window, "EmptyHint"), "boş durum");
        Assert.Empty(Directory.GetFiles(Shots, "*.png"));
    }

    [Fact]
    public void Capture_draw_undo_unsaved_prompt_hotkey_and_shortcuts()
    {
        Window editor;
        // Yakalama ekranı kopyalar ve tam ekran üstte durur: kilit içinde.
        using (GuiLock.Acquire())
        {
            Click(_window, "CaptureButton");
            var overlay = TopWindow("Bölge Seçimi");
            Select(overlay, "Tam ekran");
            Wait(() => IsSelected(overlay, "Tam ekran") && !IsSelected(overlay, "Bölge"), "tam ekran modu");
            ClickName(overlay, "Yakala");
            editor = TopWindow("Ekran Görüntüsü Düzenleyici");
            Wait(() => !HasTopWindow("Bölge Seçimi"), "yakalama kapandı");

            // Gerçek fare: dikdörtgen + ok çiz, Ctrl+Z geri al, 1-5 araç tuşları.
            Foreground(editor);
            var canvas = editor.FindFirstDescendant(cf => cf.ByClassName("InkCanvas")) ?? editor;
            var r = canvas.BoundingRectangle;
            var c = new System.Drawing.Point(r.Left + r.Width / 2, r.Top + r.Height / 2);
            Keyboard.Type(VirtualKeyShort.KEY_2);
            Wait(() => IsSelected(editor, "▭ Dikdörtgen"), "2 tuşu");
            bool CanUndo() => editor.FindFirstDescendant(cf => cf.ByName("Geri al"))?.IsEnabled == true;
            // Gerçek fare yalnızca düzenleyicinin tuvali o noktada en üstteyse gönderilir (başka uygulamaya tıklanmasın).
            void Drag(System.Drawing.Point from, System.Drawing.Point to)
            {
                Foreground(editor);
                var hit = _automation.FromPoint(from);
                Assert.True(hit.Properties.ProcessId.ValueOrDefault == _app.ProcessId, "Tuval başka bir pencerenin altında");
                Mouse.Drag(from, to);
            }
            Drag(c, new System.Drawing.Point(c.X + 120, c.Y + 80));
            Wait(CanUndo, "çizim geri alınabilir");
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_Z);
            Wait(() => !CanUndo(), "Ctrl+Z geri aldı");
            Keyboard.Type(VirtualKeyShort.KEY_1);
            Wait(() => IsSelected(editor, "➚ Ok"), "1 tuşu");
            Drag(new System.Drawing.Point(c.X - 100, c.Y - 60), c);
            Wait(CanUndo, "ok çizildi");
            Foreground(editor); // bildirimler odağı alabilir
            Keyboard.Type(VirtualKeyShort.KEY_5);
            Wait(() => IsSelected(editor, "▦ Gizle"), "5 tuşu");

            // Esc: kaydedilmemiş işaretleme -> onay; Hayır -> düzenleyici açık kalır.
            Foreground(editor);
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            try { Dialog(editor); }
            catch (TimeoutException)
            {
                var wins = string.Join(" | ", _app.GetAllTopLevelWindows(_automation).Select(w => w.Title + "[" + string.Join(",", w.FindAllChildren().Select(ch => ch.Properties.ControlType.ValueOrDefault + ":" + ch.Properties.Name.ValueOrDefault)) + "]"));
                throw new TimeoutException("Onay yok. Önde: " + ForegroundTitle() + " Pencereler: " + wins);
            }
        }
        Assert.Contains("kaydedilmedi", Answer(editor, "7"));
        Assert.True(HasTopWindow("Ekran Görüntüsü Düzenleyici"));

        using (GuiLock.Acquire())
        {
            Foreground(editor);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_S);
        }
        Wait(() => History().Length == 1, "Ctrl+S kaydetti", 60);
        Wait(() => _window.IsAvailable && !_window.IsOffscreen, "ana pencere geri geldi");

        // Global kısayol (Ctrl+Alt+A) yakalamayı açar; Esc iptal eder ve ana pencere döner.
        using (GuiLock.Acquire())
        {
            if (!Text(_window, "StatusText").Contains("kaydedilemedi"))
            {
                Keyboard.Press(VirtualKeyShort.CONTROL);
                Keyboard.Press(VirtualKeyShort.ALT);
                Keyboard.Type(VirtualKeyShort.KEY_A);
                Keyboard.Release(VirtualKeyShort.ALT);
                Keyboard.Release(VirtualKeyShort.CONTROL);
                var overlay = TopWindow("Bölge Seçimi");
                Foreground(overlay);
                Keyboard.Type(VirtualKeyShort.ESCAPE);
                Wait(() => !HasTopWindow("Bölge Seçimi"), "Esc yakalamayı iptal etti");
            }

            // Ana pencere kısayolları: Ctrl+F arama, Esc temizler, Ctrl+O görsel aç.
            Wait(() => !_window.IsOffscreen, "ana pencere");
            Foreground(_window);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_F);
            Keyboard.Type("zzz");
            Wait(() => History().Length == 0, "Ctrl+F arama");
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Wait(() => History().Length == 1, "Esc temizler");
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_O);
            Dialog(_window);
        }
        CancelDialog(_window);
    }
}

/// <summary>Repo kökündeki .gui.lock: agent'lar masaüstünü paylaşır; gerçek girdi/ekran kopyası yalnızca kilit içinde.</summary>
internal static class GuiLock
{
    public static FileStream Acquire()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, ".git")))
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
