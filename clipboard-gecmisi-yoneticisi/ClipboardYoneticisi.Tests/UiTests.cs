using System.IO;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using Xunit;
using Window = FlaUI.Core.AutomationElements.Window;

namespace ClipboardYoneticisi.Tests;

/// <summary>
/// FlaUI (UIA3) arayuz testleri: gercek exe gecici veri klasoruyle acilir; pano icerigi test sonunda geri yuklenir.
/// Yalnizca run.ps1 -UiTest ile calisir (Category=UI). Gercek fare/klavye adimlari ortak .gui.lock icindedir.
/// Ekran goruntusu: CGY_EKRAN_DIR ortam degiskeni verilirse panel/ayarlar PNG olarak oraya yazilir.
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IClassFixture<ClipboardSnapshot>
{
    private const string PanelTitle = "Pano Geçmişi";
    private static readonly string? ShotDir = Environment.GetEnvironmentVariable("CGY_EKRAN_DIR");

    private static readonly string[] Demo =
    [
        "Toplantı notu: Perşembe 14:00 — sunum taslağı ve bütçe özeti",
        "https://example.com/raporlar/2026-ceyrek-3",
        "const toplam = fiyatlar.reduce((a, b) => a + b, 0);",
        "destek@example.com",
    ];

    private static AutomationElement ById(AutomationElement root, string id) =>
        Ui.Retry(() => root.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private static ListBoxItem[] Rows(Window panel) =>
        panel.FindFirstDescendant(cf => cf.ByAutomationId("HistoryList"))?.AsListBox().Items ?? [];

    private static bool Visible(Window panel, string id) =>
        panel.FindFirstDescendant(cf => cf.ByAutomationId(id)) is { IsOffscreen: false };

    private static Window Panel(AppUnderTest app) => app.WaitWindow(PanelTitle);

    /// <summary>Demo verisi gercek akistan gelir: panoya yazilir, uygulama yakalar.</summary>
    private static void Seed(Window panel, bool withImage = false)
    {
        var expected = Rows(panel).Length;
        if (withImage)
        {
            Pano.CopyDemoImage();
            var n = ++expected;
            Ui.Wait(() => Rows(panel).Length == n, "gorsel yakalandi");
        }
        foreach (var text in Demo.Reverse())
        {
            Pano.CopyText(text);
            var n = ++expected;
            Ui.Wait(() => Rows(panel).Length == n, "yakalandi: " + text);
        }
    }

    /// <summary>Menu dugmesi -> oge. Acilir menu baska pencere odak alinca kapanabilir: birkac kez dene.</summary>
    private static void OpenMenu(AppUnderTest app, Window panel, string item)
    {
        for (var attempt = 1; ; attempt++)
        {
            ById(panel, "MenuButton").AsButton().Invoke();
            try
            {
                Ui.InvokeNoWait(MenuItem(app, item, seconds: 3));
                return;
            }
            catch (TimeoutException) when (attempt < 3) { }
        }
    }

    /// <summary>MessageBox: metni dogrula, verilen dugmeyle kapat (1=Tamam, 6=Evet, 7=Hayir).</summary>
    private static void AnswerMessage(AppUnderTest app, string title, string contains, string buttonId = "2")
    {
        var box = app.WaitWindow(title);
        Ui.Wait(() => AppUnderTest.HasText(box, contains), $"mesaj '{contains}'");
        // Dugme mesaj kutusu tam hazir olmadan basilirsa yok sayilabiliyor: kapanana kadar tekrar bas.
        Ui.Wait(() =>
        {
            if (app.TopWindow(title) is not { } current) return true;
            (current.FindFirstDescendant(cf => cf.ByAutomationId(buttonId))
             ?? current.FindFirstDescendant(cf => cf.ByAutomationId("1")))?.AsButton().Invoke();
            Thread.Sleep(400);
            return app.TopWindow(title) == null;
        }, "mesaj kapandi: " + title);
    }

    /// <summary>
    /// Ortak dosya diyalogu (Kaydet / Ac): test modunda gecici veri klasorunde acilir. path verilirse dosya adi
    /// kutusuna yazilir (Ac); verilmezse onerilen adla onaylanir (Kaydet).
    /// </summary>
    private static void FileDialog(AppUnderTest app, string? path)
    {
        // Sahipli diyalog: panelin altinda ya da ust duzeyde olabilir.
        AutomationElement? Find() => app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
            .Select(w => w.ClassName == "#32770" ? w : w.FindFirstDescendant(cf => cf.ByClassName("#32770")))
            .FirstOrDefault(e => e?.FindFirstDescendant(cf => cf.ByAutomationId("1148").Or(cf.ByAutomationId("1001"))) != null);
        var dlg = Ui.Retry(Find, "dosya diyalogu").AsWindow();
        var box = Ui.Retry(() =>
            dlg.FindFirstDescendant(cf => cf.ByAutomationId("1001")) ??                 // Kaydet: dosya adi
            dlg.FindFirstDescendant(cf => cf.ByAutomationId("1148"))?                    // Ac: dosya adi birlesik kutusu
               .FindFirstDescendant(cf => cf.ByControlType(ControlType.Edit)), "dosya adi kutusu");
        if (path != null)
        {
            box.AsTextBox().Text = path;
            Ui.Wait(() => box.AsTextBox().Text.Contains(path), "dosya adi yazildi");
        }
        // "Ac" bir SplitButton: UIA Invoke her zaman onaylamiyor. Kapanmazsa kilit icinde Enter (dosya adi kutusunda).
        var tries = 0;
        Ui.Wait(() =>
        {
            if (Find() == null) return true;
            if (++tries < 3)
                dlg.FindFirstChild(cf => cf.ByAutomationId("1"))?.Patterns.Invoke.PatternOrDefault?.Invoke();
            else
                using (GuiLock.Acquire())
                {
                    Focus(dlg);
                    box.Focus();
                    Keyboard.Type(VirtualKeyShort.RETURN);
                }
            Thread.Sleep(700);
            return Find() == null;
        }, "dosya diyalogu onaylandi", 20);
    }

    [Fact]
    public void Panel_capture_search_filter_multiselect_and_menu_dialogs()
    {
        using var app = new AppUnderTest();
        var panel = Panel(app);

        // Bos durum + erisilebilir adlar
        Assert.Equal("Henüz kopyalanan öğe yok", ById(panel, "EmptyStateText").Name);
        Assert.Equal("Geçmişte ara", ById(panel, "SearchBox").Name);
        Assert.Equal("Menü", ById(panel, "MenuButton").Name);

        // Yakalama: metin, URL, kod, e-posta, gorsel
        Seed(panel, withImage: true);
        Assert.Equal(Demo[0], Rows(panel)[0].Name); // satir adi = onizleme metni (sinif adi degil)
        Assert.Equal("Ekran görüntüsü", Rows(panel)[^1].Name);
        if (ShotDir != null) Ui.SaveWindowPng(panel, Path.Combine(ShotDir, "panel.png"));

        // Arama + bos sonuc
        var search = ById(panel, "SearchBox").AsTextBox();
        search.Text = "rapor";
        Ui.Wait(() => Rows(panel).Length == 1, "arama 1 sonuc");
        search.Text = "zzz-yok";
        Ui.Wait(() => Rows(panel).Length == 0 && Visible(panel, "EmptyStateText"), "bos arama");
        Assert.Equal("Eşleşme bulunamadı", ById(panel, "EmptyStateText").Name);
        search.Text = "";
        Ui.Wait(() => Rows(panel).Length == 5, "arama temizlendi");

        // Filtre cipleri
        void Filter(string label, int count)
        {
            Ui.Retry(() => panel.FindFirstDescendant(cf => cf.ByControlType(ControlType.Button).And(cf.ByName(label))), label).AsButton().Invoke();
            Ui.Wait(() => Rows(panel).Length == count, $"filtre {label} = {count}");
        }
        Filter("URL", 1);
        Filter("Kod", 1);
        Filter("Görsel", 1);
        Filter("Metin", 2); // metin + e-posta
        Filter("Tümü", 5);

        // Coklu secim (Shift+Asagi, gercek tus; UIA AddToSelection WPF'te secimi tek ogeye indirebiliyor)
        // -> secim cubugu -> stack'e ekle
        var rows = Rows(panel);
        rows[0].Select();
        using (GuiLock.Acquire())
        {
            Focus(panel);
            rows[0].Focus();
            ShiftDown();
        }
        Ui.Wait(() => Visible(panel, "MultiStackButton"), "secim cubugu");
        Assert.True(AppUnderTest.HasText(panel, "2 seçili"));
        ById(panel, "MultiStackButton").AsButton().Invoke();
        Ui.Wait(() => ById(panel, "StackCountText").Name == "Stack 2", "stack 2");

        // Coklu silme: onay "Hayir" -> hicbir sey silinmez; "Evet" -> 2 silinir, geri al bilgisi
        Ui.InvokeNoWait(ById(panel, "MultiDeleteButton"));
        AnswerMessage(app, "Toplu silme", "2 öğe silinsin mi?", "7");
        Assert.Equal(5, Rows(panel).Length);
        Ui.InvokeNoWait(ById(panel, "MultiDeleteButton"));
        AnswerMessage(app, "Toplu silme", "2 öğe silinsin mi?", "6");
        Ui.Wait(() => Rows(panel).Length == 3, "2 silindi");
        Assert.Equal("2 öğe silindi · Ctrl+Z geri al", ById(panel, "StatusText").Name);

        // Menu: Yardim (ayarlardaki kisayol gosterilir)
        OpenMenu(app, panel, "Yardım");
        var help = app.WaitWindow("Klavye kısayolları");
        Assert.True(AppUnderTest.HasText(help, AppUnderTest.ShowHotkey));
        ById(help, "CloseButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Klavye kısayolları") == null, "yardim kapandi");

        // Menu: Hakkinda -> surum + elle guncelleme kontrolu (otomatik kontrol kapaliyken de calisir)
        OpenMenu(app, panel, "Hakkında");
        var about = app.WaitWindow("Hakkında");
        Assert.StartsWith("Sürüm ", ById(about, "VersionText").Name);
        Ui.InvokeNoWait(ById(about, "CheckUpdatesButton"));
        AnswerMessage(app, "Güncelleme", "Güncel sürümü kullanıyorsunuz");
        Assert.NotNull(app.Settings().LastUpdateCheckUtc);
        ById(about, "CloseButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Hakkında") == null, "hakkinda kapandi");

        // Menu: Ayarlar -> gecersiz deger uyarisi, ayni kisayol uyarisi, kaydet
        OpenMenu(app, panel, "Ayarlar");
        var settings = app.WaitWindow("Ayarlar");
        if (ShotDir != null) Ui.SaveWindowPng(settings, Path.Combine(ShotDir, "ayarlar.png"));
        var limit = ById(settings, "HistoryLimitBox").AsTextBox();
        Assert.Equal("Geçmiş limiti", limit.Name);
        limit.Text = "5";
        Ui.InvokeNoWait(ById(settings, "SaveButton"));
        AnswerMessage(app, "Geçersiz değer", "10 ile 5000");
        limit.Text = "300";
        ById(settings, "StackHotkeyBox").AsTextBox().Text = AppUnderTest.ShowHotkey;
        Ui.InvokeNoWait(ById(settings, "SaveButton"));
        AnswerMessage(app, "Geçersiz değer", "farklı olmalıdır");
        ById(settings, "StackHotkeyBox").AsTextBox().Text = AppUnderTest.StackHotkey;
        ById(settings, "NotifyOnCaptureCheck").AsCheckBox().IsChecked = false;
        Ui.InvokeNoWait(ById(settings, "SaveButton"));
        Ui.Wait(() => app.TopWindow("Ayarlar") == null, "ayarlar kaydedildi");
        Assert.Equal(300, app.Settings().HistoryLimit);
        Assert.False(app.Settings().NotifyOnCapture);

        // Menu: Ayarlar -> Iptal degisiklik yazmaz
        OpenMenu(app, panel, "Ayarlar");
        settings = app.WaitWindow("Ayarlar");
        ById(settings, "HistoryLimitBox").AsTextBox().Text = "999";
        ById(settings, "CancelButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Ayarlar") == null, "ayarlar iptal");
        Assert.Equal(300, app.Settings().HistoryLimit);

        // Menu: Yedekle -> Kaydet diyalogu -> bilgi mesaji
        OpenMenu(app, panel, "Yedekle…");
        FileDialog(app, null);
        AnswerMessage(app, "Yedekleme", "3 öğe dışa aktarıldı", "2");
        var backup = Assert.Single(Directory.GetFiles(app.DataDir, "clipboard-yedek-*.json"));

        // Menu: Gecmisi temizle -> Hayir korur, Evet siler
        OpenMenu(app, panel, "Geçmişi temizle");
        AnswerMessage(app, "Geçmişi temizle", "Sabitlenmiş öğeler korunur", "7");
        Assert.Equal(3, Rows(panel).Length);
        OpenMenu(app, panel, "Geçmişi temizle");
        AnswerMessage(app, "Geçmişi temizle", "Sabitlenmiş öğeler korunur", "6");
        Ui.Wait(() => Rows(panel).Length == 0, "gecmis temizlendi");

        // Menu: Ice aktar -> Ac diyalogu veri klasorunde acilir, yedek listelenir; Iptal hicbir sey yapmaz.
        // (Win11 "Ac" SplitButton'u UIA ile guvenilir onaylanamiyor; ice aktarma+birlestirme birim testinde.)
        OpenMenu(app, panel, "İçe aktar…");
        var openDlg = Ui.Retry(() => app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
            .Select(w => w.FindFirstDescendant(cf => cf.ByClassName("#32770"))).FirstOrDefault(e => e != null), "ac diyalogu");
        Ui.Wait(() => AppUnderTest.HasText(openDlg, Path.GetFileNameWithoutExtension(backup)), "yedek dosyasi listede");
        openDlg.FindFirstChild(cf => cf.ByAutomationId("2"))!.AsButton().Invoke();
        Ui.Wait(() => app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
            .All(w => w.FindFirstDescendant(cf => cf.ByClassName("#32770")) == null), "ac diyalogu iptal");
        Assert.Empty(Rows(panel));

        // Menu: Stack'i temizle
        OpenMenu(app, panel, "Stack'i temizle");
        Ui.Wait(() => ById(panel, "StackCountText").Name == "Stack 0", "stack temizlendi");

        // Ayni veri klasoruyle ikinci ornek: "Zaten acik" uyarisi ve cikis (tek-ornek kilidi)
        using (var second = System.Diagnostics.Process.Start(app.StartInfo())!)
        {
            var box = Ui.Retry(() => app.Automation.GetDesktop()
                .FindFirstChild(app.Cf.ByProcessId(second.Id).And(app.Cf.ByName("Zaten açık"))), "zaten acik");
            (box.FindFirstDescendant(cf => cf.ByAutomationId("2")) ?? box.FindFirstDescendant(cf => cf.ByAutomationId("1")))!.AsButton().Invoke();
            Assert.True(second.WaitForExit(10000), "ikinci ornek kapanmali");
        }

        // Menu: Cikis
        OpenMenu(app, panel, "Çıkış");
        Ui.Wait(() => app.App.HasExited, "cikis");
    }

    [Fact]
    public void Encryption_setup_lock_wrong_and_right_password()
    {
        using var app = new AppUnderTest();
        var panel = Panel(app);
        Pano.CopyText(Demo[0]);
        Ui.Wait(() => Rows(panel).Length == 1, "yakalandi");

        // Sifreli mod: ayarlar -> parola belirleme penceresi
        OpenMenu(app, panel, "Ayarlar");
        var settings = app.WaitWindow("Ayarlar");
        ById(settings, "EnableEncryptionCheck").AsCheckBox().IsChecked = true;
        Ui.InvokeNoWait(ById(settings, "SaveButton"));
        var setup = app.WaitWindow("Oturum Kilidi");
        Assert.True(AppUnderTest.HasText(setup, "Şifreli mod — parola belirleyin"));
        // Bos parola uyarisi
        Ui.InvokeNoWait(ById(setup, "UnlockButton"));
        AnswerMessage(app, "Uyarı", "Parola boş olamaz");
        ById(setup, "PasswordBox").Patterns.Value.Pattern.SetValue("dogru-parola-42");
        ById(setup, "UnlockButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Ayarlar") == null, "ayarlar kapandi");
        Assert.True(app.Settings().EnableEncryption);
        Ui.Wait(() => AppUnderTest.HasText(panel, "Şifreli"), "sifreli rozeti");
        Assert.Single(Rows(panel));

        // Kilitle (menude yalnizca sifreli modda gorunur) -> liste gizlenir
        OpenMenu(app, panel, "Oturumu kilitle");
        Ui.Wait(() => Visible(panel, "UnlockButton") && Rows(panel).Length == 0, "kilitli");

        // Yanlis parola -> uyari, kilitli kalir
        Ui.InvokeNoWait(ById(panel, "UnlockButton"));
        var lockWin = app.WaitWindow("Oturum Kilidi");
        ById(lockWin, "PasswordBox").Patterns.Value.Pattern.SetValue("yanlis");
        ById(lockWin, "UnlockButton").AsButton().Invoke();
        AnswerMessage(app, "Kilit", "Parola hatalı");
        Assert.True(Visible(panel, "UnlockButton"));

        // Dogru parola -> gecmis geri gelir (sifreli kayit cozulur)
        Ui.InvokeNoWait(ById(panel, "UnlockButton"));
        lockWin = app.WaitWindow("Oturum Kilidi");
        ById(lockWin, "PasswordBox").Patterns.Value.Pattern.SetValue("dogru-parola-42");
        ById(lockWin, "UnlockButton").AsButton().Invoke();
        Ui.Wait(() => Rows(panel).Length == 1 && !Visible(panel, "UnlockButton"), "kilit acildi");
        Assert.Equal(Demo[0], Rows(panel)[0].Name);

        // Sifreli modda ayni metin tekrar kopyalaninca yeni kayit acilmaz (rastgele IV'ye ragmen tekillestirme)
        Pano.CopyText(Demo[0]);
        Pano.CopyText(Demo[1]);
        Ui.Wait(() => Rows(panel).Length == 2, "ikinci metin yakalandi");
        Pano.CopyText(Demo[0]);
        Ui.Wait(() => Rows(panel)[0].Name == Demo[0], "tekrar kopyalanan basa gelir");
        Assert.Equal(2, Rows(panel).Length);
    }

    [Fact]
    public void First_run_welcome_tray_icon_and_tray_menu()
    {
        using var app = new AppUnderTest(firstRun: true, startHidden: true);

        // Ilk acilis: hosgeldin penceresi, ayarlardaki kisayolu gosterir
        var welcome = app.WaitWindow("Hoş geldiniz");
        Assert.True(AppUnderTest.HasText(welcome, AppUnderTest.ShowHotkey));
        Assert.Null(app.TopWindow(PanelTitle)); // tepsiye kucultulmus baslar
        ById(welcome, "StartButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Hoş geldiniz") == null, "hosgeldin kapandi");
        Assert.True(app.Settings().FirstRunCompleted);

        // Tepsi simgesi: gizli simgeler tasmasinda olabilir; sol tik (UIA Invoke) paneli acar
        var icon = TrayIcon(app);
        icon.Patterns.Invoke.Pattern.Invoke();
        var panel = Panel(app);
        Ui.Wait(() => !panel.IsOffscreen, "panel tepsiden acildi");

        // Esc paneli gizler (gercek tus: kilit icinde, pencere on plandayken)
        using (GuiLock.Acquire())
        {
            Focus(panel);
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Ui.Wait(() => app.TopWindow(PanelTitle) == null, "Esc paneli gizler");

            // Sag tik: tepsi menusu (gercek fare). Tasma penceresi kendiliginden kapanabilir: birkac kez dene.
            for (var attempt = 1; ; attempt++)
            {
                icon = TrayIcon(app);
                var r = icon.BoundingRectangle;
                Mouse.RightClick(new System.Drawing.Point(r.X + r.Width / 2, r.Y + r.Height / 2));
                try
                {
                    Ui.InvokeNoWait(MenuItem(app, "Hakkında", seconds: 3));
                    break;
                }
                catch (TimeoutException) when (attempt < 3)
                {
                    Keyboard.Type(VirtualKeyShort.ESCAPE);
                }
                catch (TimeoutException)
                {
                    // Win11 gizli simge tasmasi sag tikta bazen kapanir; ayni menu ⋯ dugmesiyle tam test ediliyor.
                    Keyboard.Type(VirtualKeyShort.ESCAPE);
                    Assert.Skip("Tepsi sag tik menusu acilamadi (tasma penceresi kapandi); menu ogeleri diger testte dogrulandi.");
                }
            }
        }
        var aboutWin = app.WaitWindow("Hakkında");
        ById(aboutWin, "CloseButton").AsButton().Invoke();
        Ui.Wait(() => app.TopWindow("Hakkında") == null, "hakkinda kapandi");
    }

    [Fact]
    public void Keyboard_shortcuts_global_hotkeys_and_undo()
    {
        using var app = new AppUnderTest();
        var panel = Panel(app);
        Seed(panel);
        var rows = Rows(panel);
        rows[1].Select(); // URL

        using (GuiLock.Acquire())
        {
            // Paylasilan masaustu: her tus grubundan once pencerenin on planda oldugunu garanti et.
            Focus(panel);
            rows[1].Focus();

            // Enter: panoya al
            Keyboard.Type(VirtualKeyShort.RETURN);
            Ui.Wait(() => Pano.Text() == Demo[1], "Enter panoya alir");

            // Ctrl+P: sabitle -> "SABITLENMIS" basligi
            Focus(panel);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_P);
            Ui.Wait(() => AppUnderTest.HasText(panel, "SABİTLENMİŞ"), "Ctrl+P sabitler");

            // Delete + Ctrl+Z geri al (sabitleme de geri gelir)
            Focus(panel);
            Ui.Retry(() => Rows(panel).FirstOrDefault(r => r.Name == Demo[1]), "url satiri").Focus();
            Keyboard.Type(VirtualKeyShort.DELETE);
            Ui.Wait(() => Rows(panel).Length == 3, "Delete siler");
            Assert.Equal("1 öğe silindi · Ctrl+Z geri al", ById(panel, "StatusText").Name);
            Focus(panel);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_Z);
            Ui.Wait(() => Rows(panel).Length == 4, "Ctrl+Z geri alir");
            Assert.Equal("1 öğe geri alındı", ById(panel, "StatusText").Name);
            Assert.True(AppUnderTest.HasText(panel, "SABİTLENMİŞ"));

            // Ctrl+F arama, Asagi ok listeye gecer
            Focus(panel);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_F);
            Keyboard.Type("toplam");
            Ui.Wait(() => Rows(panel).Length == 1, "Ctrl+F ile arama");
            Keyboard.Type(VirtualKeyShort.DOWN);
            Ui.Wait(() => Rows(panel)[0].IsSelected, "ok tusu ilk satiri secer");

            // F1 yardim, Esc kapatir (IsCancel)
            Focus(panel);
            Keyboard.Type(VirtualKeyShort.F1);
            var help = app.WaitWindow("Klavye kısayolları");
            ById(help, "CloseButton").AsButton().Invoke();
            Ui.Wait(() => app.TopWindow("Klavye kısayolları") == null, "yardim kapandi");

            // Esc paneli gizler; global kisayol (odak gerekmez) tekrar acar, arama kutusu odakli
            Focus(panel);
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Ui.Wait(() => app.TopWindow(PanelTitle) == null, "Esc gizler");
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.ALT, VirtualKeyShort.SHIFT, VirtualKeyShort.F9);
            panel = Panel(app);
            Ui.Wait(() => ById(panel, "SearchBox").Properties.HasKeyboardFocus.Value, "global kisayol paneli acar, arama odakli");

            // Aramayi temizle, listeye in, Shift+Asagi ile coklu secim (gercek kullanici akisi)
            Focus(panel);
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
            Keyboard.Type(VirtualKeyShort.BACK);
            Ui.Wait(() => Rows(panel).Length == 4, "arama temizlendi");
            Rows(panel)[1].Select();
            Rows(panel)[1].Focus();
            Focus(panel);
            ShiftDown();
            Ui.Wait(() => Visible(panel, "MultiStackButton"), "Shift+Asagi coklu secim");
            Assert.True(AppUnderTest.HasText(panel, "2 seçili"));
        }

        // Secili iki oge stack'e; global stack kisayolu her basista siradakini panoya yazar ve paneli gizler
        rows = Rows(panel);
        var selected = rows.Where(r => r.IsSelected).Select(r => r.Name).ToHashSet();
        Assert.Equal(2, selected.Count);
        ById(panel, "MultiStackButton").AsButton().Invoke();
        Ui.Wait(() => ById(panel, "StackCountText").Name == "Stack 2", "stack 2");
        Pano.CopyText("stack-oncesi"); // panoda secili ogelerden biri kalmasin
        Ui.Wait(() => Rows(panel).Length == 5, "ara kopya");
        var pasted = new HashSet<string>();
        using (GuiLock.Acquire())
        {
            for (var i = 0; i < 2; i++)
            {
                var before = Pano.Text();
                Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.ALT, VirtualKeyShort.SHIFT, VirtualKeyShort.F10);
                Ui.Wait(() => Pano.Text() != before, "stack kisayolu panoya yazar");
                pasted.Add(Pano.Text()!);
            }
        }
        Assert.True(selected.SetEquals(pasted), $"secili=[{string.Join(" | ", selected)}] yapistirilan=[{string.Join(" | ", pasted)}]");
        Ui.Wait(() => app.TopWindow(PanelTitle) == null, "stack yapistirma paneli gizler");
    }

    /// <summary>Acik baglam menusundeki oge (menu, surecin ayri bir acilir penceresidir).</summary>
    private static AutomationElement MenuItem(AppUnderTest app, string name, double seconds = 10) =>
        Ui.Retry(() => app.Automation.GetDesktop().FindAllChildren(cf => cf.ByProcessId(app.Pid))
            .Select(w => w.FindFirstDescendant(cf => cf.ByControlType(ControlType.MenuItem).And(cf.ByName(name))))
            .FirstOrDefault(e => e != null), "menu: " + name, seconds);

    /// <summary>
    /// Shift+Asagi: ok tusu genisletilmis tarama koduyla gonderilmeli; aksi halde NumLock acikken Windows
    /// Shift'i birakilmis sayar (sanal tusla Shift+Down duz Down olur).
    /// </summary>
    private static void ShiftDown()
    {
        Keyboard.Press(VirtualKeyShort.SHIFT);
        Keyboard.TypeScanCode(0x50, isExtendedKey: true);
        Keyboard.Release(VirtualKeyShort.SHIFT);
    }

    /// <summary>
    /// Pencereyi on plana al (cagiran .gui.lock'u tutar). SetForegroundWindow, kalici bir bildirim (toast) gibi
    /// baska bir surec on plandayken reddedilebilir; o zaman pencerenin basligina gercek tik ile etkinlestir.
    /// </summary>
    private static void Focus(Window w)
    {
        var hwnd = w.Properties.NativeWindowHandle.Value;
        var tries = 0;
        Ui.Wait(() =>
        {
            if (Ui.GetForegroundWindow() == hwnd) return true;
            if (++tries % 5 == 0)
            {
                var r = w.BoundingRectangle;
                Mouse.Click(new System.Drawing.Point(r.X + r.Width / 2, r.Y + 12)); // baslik cubugu
            }
            else
            {
                Ui.ForceForeground(hwnd);
            }
            Thread.Sleep(150);
            return Ui.GetForegroundWindow() == hwnd;
        }, "pencere on planda", 20);
    }

    /// <summary>Gorev cubugu ya da gizli simgeler tasmasi icinde uygulamanin tepsi dugmesi.</summary>
    private static AutomationElement TrayIcon(AppUnderTest app)
    {
        const string name = "Pano Geçmişi Yöneticisi (test)";
        var desktop = app.Automation.GetDesktop();
        AutomationElement? Find() =>
            new[] { "Shell_TrayWnd", "TopLevelWindowForOverflowXamlIsland" }
                .Select(c => desktop.FindFirstChild(cf => cf.ByClassName(c)))
                .SelectMany(root => root?.FindAllDescendants(cf => cf.ByAutomationId("NotifyItemIcon")) ?? [])
                .FirstOrDefault(e => e.Name.Trim() == name && !e.IsOffscreen && !e.BoundingRectangle.IsEmpty);

        if (Find() is { } visible) return visible;
        var tray = desktop.FindFirstChild(cf => cf.ByClassName("Shell_TrayWnd"));
        var chevron = Ui.Retry(() => tray!.FindFirstDescendant(cf => cf.ByAutomationId("SystemTrayIcon").And(cf.ByClassName("SystemTray.NormalButton"))), "gizli simgeler");
        chevron.Patterns.Invoke.Pattern.Invoke();
        return Ui.Retry(Find, "tepsi simgesi");
    }
}
