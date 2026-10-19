using System.IO;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using Xunit;
using Window = FlaUI.Core.AutomationElements.Window;

namespace EkranRenkSecici.Tests;

/// <summary>
/// FlaUI (UIA3) arayuz testleri. Yalnizca run.ps1 -UiTest ile calisir (Category=UI). Gercek tus/fare ve ekran
/// kopyalama (secim katmani acilirken ekran yakalanir) ortak .gui.lock icinde. Pano test sonunda geri yuklenir.
/// ERS_EKRAN_DIR verilirse ana pencere PNG olarak oraya yazilir.
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IClassFixture<ClipboardSnapshot>
{
    private const string MainTitle = "Ekran Renk Seçici";
    private readonly ClipboardSnapshot _clip;

    public UiTests(ClipboardSnapshot clip) => _clip = clip;

    private static AutomationElement ById(AutomationElement root, string id) =>
        Ui.Retry(() => root.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private static AutomationElement ByName(AutomationElement root, string name) =>
        Ui.Retry(() => root.FindFirstDescendant(cf => cf.ByName(name)), name);

    private static ListBoxItem[] History(Window w) => ById(w, "HistoryList").AsListBox().Items;

    private static string Status(Window w) => ById(w, "StatusText").Name;

    private string Clip()
    {
        var t = Pano.Text() ?? "";
        _clip.Written.Add(t);
        return t;
    }

    /// <summary>Pencere tepsiden acilir (baslangicta gizli): tepsi simgesine sol tik (UIA Invoke).</summary>
    private static Window ShowFromTray(AppUnderTest app)
    {
        Ui.Wait(() => app.App.HasExited || app.FindWindow(MainTitle) == null, "baslangicta tepsiye gizlenir");
        app.TrayIcon().Patterns.Invoke.Pattern.Invoke();
        return app.WaitWindow(MainTitle);
    }

    /// <summary>Renk kodu kutusu: deger UIA ile yazilir, Enter gercek tus (KeyBinding).</summary>
    private static void EnterColor(Window main, string text)
    {
        var box = ById(main, "ColorInputBox");
        box.AsTextBox().Text = text;
        using (GuiLock.Acquire())
        {
            Ui.Focus(main);
            box.Focus();
            Keyboard.Type(VirtualKeyShort.RETURN);
        }
    }

    [Fact]
    public void Main_window_color_input_details_export_settings_and_clear()
    {
        using var app = new AppUnderTest();
        var main = ShowFromTray(app);

        // Bos durum + kisayol ayardan
        Assert.True(Ui.HasText(main, "Ekrandan bir renk seçin"));
        Assert.Equal($"Ekrandan Seç ({AppUnderTest.HotkeyDisplay})", ById(main, "CaptureButton").Name);
        Assert.Contains(AppUnderTest.HotkeyDisplay, Status(main));

        // Gecersiz ve gecerli renk kodu
        EnterColor(main, "zzz");
        Ui.Wait(() => Status(main).StartsWith("Geçersiz renk"), "gecersiz renk mesaji");
        EnterColor(main, "#3B82F6");
        Ui.Wait(() => History(main).Length == 1, "gecmise eklendi");
        EnterColor(main, "rgb(16, 185, 129)");
        Ui.Wait(() => History(main).Length == 2, "ikinci renk");
        Assert.Equal("#10B981", History(main)[0].Name); // satir adi = HEX (sinif adi degil)
        Assert.Equal("Seçili: #10B981", Status(main));
        if (Environment.GetEnvironmentVariable("ERS_EKRAN_DIR") is { } shots)
            Ui.SaveWindowPng(main, Path.Combine(shots, "ana.png"));

        // Kopyala dugmeleri (her biri ayri erisilebilir ad)
        ByName(main, "HEX kopyala").AsButton().Invoke();
        Ui.Wait(() => Clip() == "#10B981", "HEX panoda");
        Assert.Equal("HEX panoya kopyalandı", Status(main));
        ByName(main, "RGB kopyala").AsButton().Invoke();
        Ui.Wait(() => Clip().StartsWith("rgb(16"), "RGB panoda");
        foreach (var f in new[] { "HSL", "OKLCH", "CSS" })
        {
            ByName(main, f + " kopyala").AsButton().Invoke();
            Ui.Wait(() => Status(main) == f + " panoya kopyalandı", f);
        }

        // Kontrast arka plan secimleri ve renk korlugu
        var ratio = ById(main, "ContrastRatioText");
        ByName(main, "Koyu").AsButton().Invoke();
        var dark = ratio.Name;
        ByName(main, "Beyaz").AsButton().Invoke();
        Ui.Wait(() => ratio.Name != dark, "kontrast degisti");
        ByName(main, "Tamamlayıcı").AsButton().Invoke();
        foreach (var t in new[] { "Protan", "Deutan", "Tritan", "Orijinal" })
            ByName(main, t).AsButton().Invoke();

        // Tamamlayici renk ve analog palet: tikla -> HEX panoya
        var comp = ById(main, "ComplementaryButton");
        var compHex = comp.Name.Replace(" kopyala", "");
        comp.AsButton().Invoke();
        Ui.Wait(() => Clip() == compHex, "tamamlayici panoda");
        var analog = Ui.Retry(() => main.FindAllDescendants(cf => cf.ByControlType(ControlType.Button))
            .FirstOrDefault(b => b.Name.EndsWith(" kopyala") && b.Name.StartsWith('#') && b.AutomationId != "ComplementaryButton"), "analog renk");
        analog.AsButton().Invoke();
        Ui.Wait(() => Clip() == analog.Name.Replace(" kopyala", ""), "analog panoda");

        // Gecmisten secim
        History(main)[1].Select();
        Ui.Wait(() => Status(main) == "Seçili: #3B82F6", "gecmisten secim");

        // Disa aktar: sekmeler + kopyala ve kapat
        Ui.InvokeNoWait(ById(main, "ExportButton"));
        var export = app.WaitWindow("Token Export");
        var text = ById(export, "ExportText").AsTextBox();
        var tailwind = text.Text;
        Assert.Contains("#3B82F6", tailwind, StringComparison.OrdinalIgnoreCase);
        ById(export, "TabFigma").AsButton().Invoke();
        Ui.Wait(() => text.Text != tailwind, "Figma sekmesi");
        ById(export, "TabCss").AsButton().Invoke();
        Ui.Wait(() => text.Text.Contains("--"), "CSS sekmesi");
        var css = text.Text;
        ById(export, "CopyButton").AsButton().Invoke();
        Ui.Wait(() => app.FindWindow("Token Export") == null, "disa aktar kapandi");
        Ui.Wait(() => Clip() == css, "disa aktarim panoda");

        // Ayarlar: Iptal yazmaz; Kaydet yazar ve kisayol etiketi guncellenir
        Ui.InvokeNoWait(ById(main, "SettingsButton"));
        var settings = app.WaitWindow("Ayarlar");
        ById(settings, "FormatCombo").AsComboBox().Select("RGB");
        ById(settings, "CancelButton").AsButton().Invoke();
        Ui.Wait(() => app.FindWindow("Ayarlar") == null, "ayarlar iptal");
        Assert.Contains("\"HEX\"", app.SettingsJson);

        Ui.InvokeNoWait(ById(main, "SettingsButton"));
        settings = app.WaitWindow("Ayarlar");
        ById(settings, "FormatCombo").AsComboBox().Select("RGB");
        ById(settings, "SampleCombo").AsComboBox().Select("5");
        ById(settings, "ZoomSlider").Patterns.RangeValue.Pattern.SetValue(12);
        ById(settings, "KeyCombo").AsComboBox().Select("J");
        ById(settings, "SaveButton").AsButton().Invoke();
        Ui.Wait(() => app.FindWindow("Ayarlar") == null, "ayarlar kaydedildi");
        var json = app.SettingsJson;
        Assert.Contains("\"RGB\"", json);
        Assert.Contains("\"SampleSize\": 5", json);
        Assert.Contains("\"MagnifierZoom\": 12", json);
        Ui.Wait(() => ById(main, "CaptureButton").Name == "Ekrandan Seç (Ctrl+Shift+Alt+J)", "kisayol etiketi");

        // Gecmisi temizle -> bos durum, dosya da bos
        ById(main, "ClearHistoryButton").AsButton().Invoke();
        Ui.Wait(() => History(main).Length == 0 && Status(main) == "Geçmiş temizlendi", "gecmis temizlendi");
        Assert.Equal("[]", File.ReadAllText(Path.Combine(app.DataDir, "history.json")));
    }

    [Fact]
    public void Selection_overlay_formats_escape_enter_and_global_hotkey()
    {
        using var app = new AppUnderTest();
        var main = ShowFromTray(app);
        const string overlayTitle = "Renk seçimi";

        using (GuiLock.Acquire()) // katman acilirken ekran kopyalanir
        {
            // Dugmeyle ac; format sekmeleri ve ornekleme dugmeleri UIA ile; Esc iptal (gecmis degismez)
            Ui.InvokeNoWait(ById(main, "CaptureButton"));
            var overlay = app.WaitWindow(overlayTitle);
            ById(overlay, "TabRgb").AsButton().Invoke();
            Ui.Wait(() => ById(overlay, "ColorValueText").Name.StartsWith("rgb("), "RGB sekmesi");
            ById(overlay, "TabOklch").AsButton().Invoke();
            Ui.Wait(() => ById(overlay, "ColorValueText").Name.StartsWith("oklch("), "OKLCH sekmesi");
            ById(overlay, "BtnSample1").AsButton().Invoke();
            Ui.Wait(() => ById(overlay, "MetaText").Name.Contains("1×1"), "1x1 ornekleme");
            Ui.Focus(overlay);
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Ui.Wait(() => app.FindWindow(overlayTitle) == null, "Esc iptal");
            Assert.Empty(History(main));

            // Global kisayol acar; klavye: 5 ornekleme, Tab sonraki format, Enter onaylar -> panoya + gecmis
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.SHIFT, VirtualKeyShort.ALT, VirtualKeyShort.KEY_K);
            overlay = app.WaitWindow(overlayTitle);
            Ui.Focus(overlay);
            Keyboard.Type(VirtualKeyShort.KEY_5);
            Ui.Wait(() => ById(overlay, "MetaText").Name.Contains("5×5"), "5 tusu");
            Keyboard.Type(VirtualKeyShort.TAB); // HEX -> RGB
            Ui.Wait(() => ById(overlay, "ColorValueText").Name.StartsWith("rgb("), "Tab formati degistirir");
            var value = ById(overlay, "ColorValueText").Name;
            Keyboard.Type(VirtualKeyShort.RETURN);
            Ui.Wait(() => app.FindWindow(overlayTitle) == null, "Enter onaylar");
            Ui.Wait(() => Clip() == value, "secilen renk panoda");
        }
        Ui.Wait(() => History(main).Length == 1, "gecmise eklendi");
        Assert.EndsWith("panoya kopyalandı", Status(main));
        Assert.True(File.Exists(Path.Combine(app.DataDir, "history.json")));

        // Pencereyi kapatmak uygulamayi kapatmaz (tepsiye gizlenir)
        main.Close();
        Ui.Wait(() => app.FindWindow(MainTitle) == null, "tepsiye gizlendi");
        Assert.False(app.App.HasExited);

        // Tepsi sag tik menusu -> Cikis (gercek fare). Win11 gizli simge tasmasi bazen kapanir: 3 deneme.
        using (GuiLock.Acquire())
        {
            for (var attempt = 0; attempt < 3 && !app.App.HasExited; attempt++)
            {
                var r = app.TrayIcon().BoundingRectangle;
                Mouse.RightClick(new System.Drawing.Point(r.X + r.Width / 2, r.Y + r.Height / 2));
                try
                {
                    var exit = Ui.Retry(() => app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
                        .Select(w => w.FindFirstDescendant(cf => cf.ByControlType(ControlType.MenuItem).And(cf.ByName("Çıkış"))))
                        .FirstOrDefault(e => e != null), "tepsi menusu", 3);
                    Assert.NotNull(app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
                        .Select(w => w.FindFirstDescendant(cf => cf.ByName("Pencereyi Göster"))).FirstOrDefault(e => e != null));
                    Ui.InvokeNoWait(exit);
                    Ui.Wait(() => app.App.HasExited, "Cikis uygulamayi kapatir");
                }
                catch (TimeoutException) { Keyboard.Type(VirtualKeyShort.ESCAPE); }
            }
        }
    }
}
