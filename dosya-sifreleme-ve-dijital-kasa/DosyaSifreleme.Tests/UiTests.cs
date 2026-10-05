using System.Diagnostics;
using System.IO;
using System.Text.Json;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;
using Xunit;

namespace DosyaSifreleme.Tests;

/// <summary>
/// FlaUI (UIA3) arayüz testleri: gerçek DosyaSifreleme.exe geçici bir ayar klasörü ve geçici kasalarla açılır
/// (atılabilir parolalar). Ortak dosya diyalogları ve MessageBox'lar da UIA desenleriyle sürülür.
/// Yalnızca run.ps1 -UiTest ile çalışır (Category=UI; -Check bunları atlar).
/// </summary>
[Trait("Category", "UI")]
public sealed class UiTests : IDisposable
{
    private const string Pw = "Atilabilir-Parola-42!";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "kasa-ui-" + Guid.NewGuid().ToString("N"));
    private readonly UIA3Automation _automation = new();
    private Application? _app;
    private Window _window = null!;

    public UiTests()
    {
        // Çıkarma diyalogları geçici "cikti" klasöründe açılsın (Kaydet diyaloğu asla Belgeler'e düşmesin).
        Directory.CreateDirectory(OutDir);
        Directory.CreateDirectory(DataDir);
        File.WriteAllText(Path.Combine(DataDir, "settings.json"),
            JsonSerializer.Serialize(new { LastExportFolder = OutDir, AutoLockMinutes = 5 }));
    }

    private string DataDir => Path.Combine(_root, "ayar");
    private string VaultDir => Path.Combine(_root, "kasam");
    private string OutDir => Path.Combine(_root, "cikti");

    private void Launch(int autoLockSeconds = 0)
    {
        var psi = new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory, "DosyaSifreleme.exe"))
        {
            UseShellExecute = false,
            WorkingDirectory = _root
        };
        psi.Environment["DOSYA_SIFRELEME_DATA_DIR"] = DataDir;
        if (autoLockSeconds > 0) psi.Environment["DOSYA_SIFRELEME_AUTOLOCK_SECONDS"] = autoLockSeconds.ToString();
        _app = Application.Launch(psi);
        _window = _app.GetMainWindow(_automation, TimeSpan.FromSeconds(20))
                  ?? throw new InvalidOperationException("Ana pencere açılmadı");
        ById("SubmitButton");
    }

    private void CloseApp()
    {
        if (_app == null) return;
        _app.Close();
        try { Wait(() => _app.HasExited, "uygulama kapandı", 5); }
        catch (TimeoutException) { _app.Kill(); }
        _app.Dispose();
        _app = null;
    }

    public void Dispose()
    {
        CloseApp();
        _automation.Dispose();
        try { Directory.Delete(_root, true); } catch (IOException) { }
    }

    // --- yardımcılar ---

    private AutomationElement ById(string id) =>
        Retry(() => _window.FindFirstDescendant(cf => cf.ByAutomationId(id)), id);

    private bool Visible(string id) => _window.FindFirstDescendant(cf => cf.ByAutomationId(id)) is { IsOffscreen: false };

    private string Text(string id) => _window.FindFirstDescendant(cf => cf.ByAutomationId(id))?.Name ?? string.Empty;

    private void Click(string id) => ById(id).AsButton().Invoke();

    private ListBoxItem[] Items() =>
        _window.FindFirstDescendant(cf => cf.ByAutomationId("FileList"))?.AsListBox().Items ?? [];

    private string[] ItemNames() => Items().Select(i => i.Name).ToArray();

    private static T Retry<T>(Func<T?> f, string what, int seconds = 15) where T : class
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < TimeSpan.FromSeconds(seconds))
        {
            try { if (f() is { } r) return r; } catch (Exception) when (sw.Elapsed < TimeSpan.FromSeconds(seconds)) { }
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

    /// <summary>Ana pencereye ait kalıcı (modal) diyalog: ortak dosya diyaloğu ya da MessageBox.</summary>
    private Window Dialog() => Retry(() => _window.ModalWindows.FirstOrDefault(), "diyalog");

    private void WaitNoDialog()
    {
        try { Wait(() => _window.ModalWindows.Length == 0, "diyalog kapandı"); }
        catch (TimeoutException)
        {
            var dump = string.Join(Environment.NewLine, _window.ModalWindows.SelectMany(w => w.FindAllDescendants().Prepend(w))
                .Select(e => $"{e.Properties.ControlType.ValueOrDefault} id={e.Properties.AutomationId.ValueOrDefault} name={e.Properties.Name.ValueOrDefault}"));
            throw new TimeoutException("Diyalog kapanmadı:" + Environment.NewLine + dump);
        }
    }

    /// <summary>Win32 ortak dosya/klasör diyaloğuna tam yolu yazar ve Aç/Kaydet/Klasör Seç (Id=1) düğmesine basar.</summary>
    private void CompleteFileDialog(string path)
    {
        Assert.StartsWith(_root, path); // test asla geçici klasör dışına yazmaz
        var dlg = Dialog();
        // Aç düğmesi bölünmüş düğmedir (SplitButton); Kaydet/Klasör Seç düz düğme.
        var ok = Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("1").And(
            cf.ByControlType(ControlType.Button).Or(cf.ByControlType(ControlType.SplitButton)))), "Aç/Kaydet düğmesi");
        var edit = Retry(() =>
            dlg.FindFirstDescendant(cf => cf.ByAutomationId("1148").And(cf.ByControlType(ControlType.Edit))) // Aç
            ?? dlg.FindFirstDescendant(cf => cf.ByAutomationId("1001").And(cf.ByControlType(ControlType.Edit))) // Kaydet
            ?? dlg.FindFirstDescendant(cf => cf.ByAutomationId("1152").And(cf.ByControlType(ControlType.Edit))), // Klasör
            "dosya adı kutusu").AsTextBox();
        // Diyalog açılışta önerilen adı sonradan yazabilir (yarış): değer yerleşip sabit kalana kadar yeniden yaz.
        // Aksi halde Kaydet önerilen adla varsayılan klasöre (Belgeler) yazar.
        var sw = Stopwatch.StartNew();
        while (true)
        {
            edit.Text = path;
            Thread.Sleep(400);
            if (edit.Text == path) break;
            if (sw.Elapsed > TimeSpan.FromSeconds(10)) throw new TimeoutException("Dosya adı kutusuna yazılamadı");
        }
        ok.Patterns.Invoke.Pattern.Invoke();
        try
        {
            Wait(() => _window.ModalWindows.Length == 0, "diyalog kapandı", 3);
            return;
        }
        catch (TimeoutException) { }

        // Diyalog WM_SETTEXT değişikliğini her zaman görmez (birleşik kutu bildirimi gelmez); o zaman yolu gerçek
        // klavyeyle yaz: yalnızca bu birkaç tuş için ortak masaüstü kilidi alınır.
        using (GuiLock.Acquire())
        {
            dlg.SetForeground();
            Wait(() => GetForegroundWindow() == dlg.Properties.NativeWindowHandle.Value, "diyalog ön planda");
            edit.Focus();
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
            Keyboard.Type(path);
            Wait(() => edit.Text == path, "yol yazıldı", 5);
            Keyboard.Type(VirtualKeyShort.RETURN);
            WaitNoDialog();
        }
    }

    /// <summary>
    /// Kaydet diyaloğu: ad kutusu WM_SETTEXT ile güncellenince diyalog bunu görmez (CBN_EDITCHANGE gelmez) ve önerilen
    /// adla kaydeder. Bu yüzden ad yazılmaz; uygulama diyaloğu son çıkarma klasöründe açar (test bunu geçici klasöre
    /// ayarlar). Adres çubuğu beklenen klasörü ve ad kutusu beklenen adı göstermiyorsa kaydetmeden iptal edilir.
    /// </summary>
    private void AcceptSaveDialog(string folderName, string fileName)
    {
        var dlg = Dialog();
        var save = Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("1").And(cf.ByControlType(ControlType.Button))), "Kaydet");
        var name = Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("1001").And(cf.ByControlType(ControlType.Edit))), "ad kutusu").AsTextBox();
        bool InTempFolder() =>
            dlg.FindFirstDescendant(cf => cf.ByAutomationId("1001").And(cf.ByControlType(ControlType.ToolBar)))?
                .Properties.Name.ValueOrDefault?.EndsWith(folderName) == true;
        // Bilinen uzantılar gizliyse kutuda "rapor" görünür.
        bool NameOk() => name.Text == fileName || name.Text == Path.GetFileNameWithoutExtension(fileName);
        try { Wait(() => InTempFolder() && NameOk(), "Kaydet diyaloğu geçici klasörde"); }
        catch (TimeoutException)
        {
            var addr = dlg.FindFirstDescendant(cf => cf.ByAutomationId("1001").And(cf.ByControlType(ControlType.ToolBar)))?.Properties.Name.ValueOrDefault;
            var shown = name.Text;
            CancelDialog();
            throw new TimeoutException($"Kaydet diyaloğu beklenen yerde değil (adres: {addr}, ad: {shown}); iptal edildi.");
        }
        save.AsButton().Invoke();
        WaitNoDialog();
    }

    private void CancelDialog()
    {
        var dlg = Dialog();
        Retry(() => dlg.FindFirstDescendant(cf => cf.ByAutomationId("2").And(cf.ByControlType(ControlType.Button))), "İptal")
            .AsButton().Invoke();
        WaitNoDialog();
    }

    /// <summary>MessageBox: Evet=6, Hayır=7 (dil bağımsız Win32 kimlikleri).</summary>
    private string AnswerMessageBox(string buttonId)
    {
        var dlg = Dialog();
        var text = string.Join(" ", dlg.FindAllDescendants(cf => cf.ByControlType(ControlType.Text)).Select(t => t.Name));
        dlg.FindFirstDescendant(cf => cf.ByAutomationId(buttonId)).AsButton().Invoke();
        WaitNoDialog();
        return text;
    }

    private string Src(string name, string content)
    {
        var dir = Directory.CreateDirectory(Path.Combine(_root, "kaynak")).FullName;
        var p = Path.Combine(dir, name);
        File.WriteAllText(p, content);
        return p;
    }

    private void SetPassword(string pw) => ById("PasswordInput").Patterns.Value.Pattern.SetValue(pw);

    private void Unlock(string pw)
    {
        SetPassword(pw);
        Click("SubmitButton");
    }

    private void WaitDashboard() => Wait(() => Visible("AddButton"), "pano açıldı", 30);

    private void WaitLogin() => Wait(() => Visible("SubmitButton"), "giriş ekranı");

    // --- testler ---

    [Fact]
    public void Create_add_move_search_export_info_delete_lock_unlock()
    {
        Launch();

        // İlk açılış: hatırlanan kasa yok -> "yeni kasa" modu.
        Assert.Equal("Kasayı Oluştur ve Aç", ById("SubmitButton").Name);
        Click("ToggleModeButton");
        Wait(() => ById("SubmitButton").Name == "Kasa Aç", "giriş moduna geçti");
        Click("ToggleModeButton");
        Wait(() => ById("SubmitButton").Name == "Kasayı Oluştur ve Aç", "oluşturma moduna döndü");

        // Doğrulamalar: klasör yok, göreli yol, kısa parola.
        Click("SubmitButton");
        Wait(() => Text("ErrorText") == "Lütfen bir kasa klasörü seçin.", "klasör hatası");
        ById("VaultPathInput").AsTextBox().Text = "goreli\\kasa";
        Click("SubmitButton");
        Wait(() => Text("ErrorText").Contains("tam bir klasör yolu"), "göreli yol hatası");

        // Seç -> ortak klasör diyaloğu.
        Directory.CreateDirectory(VaultDir);
        Click("SelectFolderButton");
        CompleteFileDialog(VaultDir);
        Wait(() => ById("VaultPathInput").AsTextBox().Text.TrimEnd('\\') == VaultDir, "klasör seçildi");

        SetPassword("123");
        Click("SubmitButton");
        Wait(() => Text("ErrorText") == "Parola en az 6 karakter olmalıdır.", "kısa parola hatası");

        // Parola gücü + göster/gizle.
        SetPassword(Pw);
        Wait(() => Text("StrengthLabel").StartsWith("Çok güçlü"), "parola gücü");
        Click("TogglePasswordButton");
        Wait(() => Visible("PasswordTextInput") && ById("PasswordTextInput").AsTextBox().Text == Pw, "parola görünür");
        Click("TogglePasswordButton");
        Wait(() => !Visible("PasswordTextInput"), "parola gizlendi");

        Click("SubmitButton");
        WaitDashboard();
        Assert.True(File.Exists(Path.Combine(VaultDir, "vault.db")));
        Assert.True(Visible("EmptyText"));
        Assert.False(ById("ExportAllButton").IsEnabled);
        Assert.Equal("kasam", Text("VaultName"));

        // Ekle (kopya): Aç diyaloğu.
        var a = Src("rapor.txt", "gizli rapor içeriği");
        Click("AddButton");
        CompleteFileDialog(a);
        Wait(() => ItemNames().SequenceEqual(["rapor.txt"]), "rapor eklendi");
        Assert.True(File.Exists(a), "kopya eklemede orijinal kalır");
        Assert.Equal("Eklendi: rapor.txt", Text("StatusText"));
        Assert.Equal("1", Text("FileCount"));

        // Kasaya taşı: orijinal doğrulamadan sonra silinir.
        var b = Src("şifre-notları.md", "taşınacak not");
        ById("MoveCheckBox").AsCheckBox().IsChecked = true;
        Click("AddButton");
        CompleteFileDialog(b);
        Wait(() => Items().Length == 2, "ikinci dosya");
        Wait(() => !File.Exists(b), "orijinal silindi");
        Assert.StartsWith("Taşındı", Text("StatusText"));
        ById("MoveCheckBox").AsCheckBox().IsChecked = false;
        // Kasada düz metin yok.
        foreach (var enc in Directory.GetFiles(Path.Combine(VaultDir, "data")))
            Assert.DoesNotContain("taşınacak", File.ReadAllText(enc));

        // Ekle diyaloğu iptal: değişiklik yok.
        Click("AddButton");
        CancelDialog();
        Assert.Equal(2, Items().Length);

        // Arama: Türkçe büyük/küçük harf duyarsız; boş sonuç durumu ve temizleme.
        ById("SearchBox").AsTextBox().Text = "ŞİFRE";
        Wait(() => ItemNames().SequenceEqual(["şifre-notları.md"]), "arama");
        ById("SearchBox").AsTextBox().Text = "yok-böyle-dosya";
        Wait(() => Items().Length == 0 && Visible("NoMatchText"), "eşleşme yok");
        Assert.False(Visible("EmptyText"));
        Click("ClearSearchButton");
        Wait(() => Items().Length == 2, "arama temizlendi");

        // Çıkar: onay katmanı -> İptal.
        Assert.False(ById("ExportButton").IsEnabled);
        Items().Single(i => i.Name == "rapor.txt").Select();
        Wait(() => ById("ExportButton").IsEnabled, "seçim çıkar'ı etkinleştirir");
        Click("ExportButton");
        Wait(() => Visible("ConfirmExportButton"), "onay katmanı");
        Click("CancelExportButton");
        Wait(() => !Visible("ConfirmExportButton"), "katman kapandı");

        // Çıkar: satırdaki düğme -> onay -> Kaydet diyaloğu (son çıkarma klasöründe, önerilen adla açılır).
        ById("FileList").FindFirstDescendant(cf => cf.ByName("Çıkar: rapor.txt")).AsButton().Invoke();
        Click("ConfirmExportButton");
        AcceptSaveDialog("cikti", "rapor.txt");
        var exported = Path.Combine(OutDir, "rapor.txt");
        Wait(() => File.Exists(exported), "deşifre edilen dosya");
        Assert.Equal("gizli rapor içeriği", File.ReadAllText(exported));
        Wait(() => Text("StatusText") == "Çıkarıldı: rapor.txt", "çıkarma durumu");

        // Tümünü çıkar: klasör diyaloğu.
        var allDir = Directory.CreateDirectory(Path.Combine(_root, "yedek")).FullName;
        Click("ExportAllButton");
        CompleteFileDialog(allDir);
        Wait(() => Directory.GetFiles(allDir).Length == 2, "tümü çıkarıldı");
        Assert.Equal("taşınacak not", File.ReadAllText(Path.Combine(allDir, "şifre-notları.md")));
        Wait(() => Text("StatusText").StartsWith("2 dosya çıkarıldı"), "tümü durumu");

        // Bilgi: MessageBox.
        ById("FileList").FindFirstDescendant(cf => cf.ByName("Bilgi: rapor.txt")).AsButton().Invoke();
        var info = Dialog();
        Assert.Contains("rapor.txt", string.Join(" ", info.FindAllDescendants().Select(e => e.Properties.Name.ValueOrDefault)));
        info.Close();
        WaitNoDialog();

        // Sil: Hayır -> kalır; Evet -> silinir.
        Items().Single(i => i.Name == "rapor.txt").Select();
        Click("DeleteButton");
        Assert.Contains("rapor.txt", AnswerMessageBox("7"));
        Assert.Equal(2, Items().Length);
        Click("DeleteButton");
        AnswerMessageBox("6");
        Wait(() => ItemNames().SequenceEqual(["şifre-notları.md"]), "silindi");
        Assert.Equal("Silindi: rapor.txt", Text("StatusText"));
        Assert.Single(Directory.GetFiles(Path.Combine(VaultDir, "data")));

        // Otomatik kilit ayarı kalıcı.
        ById("AutoLockCombo").AsComboBox().Select(2); // 15 dakika
        Wait(() => File.Exists(Path.Combine(DataDir, "settings.json")) &&
                   File.ReadAllText(Path.Combine(DataDir, "settings.json")).Contains("\"AutoLockMinutes\": 15"), "ayar kaydedildi");
        Wait(() => Text("AutoLockText").StartsWith("15:00") || Text("AutoLockText").StartsWith("14:5"), "geri sayım yeni süre");

        // Kilitle -> giriş ekranı; parola kutusu boş, açma modunda.
        Click("LockButton");
        WaitLogin();
        Assert.Equal("Kasa kilitlendi.", Text("InfoText"));
        Assert.Equal("Kasa Aç", ById("SubmitButton").Name);
        Click("TogglePasswordButton"); // parola kutusu kilitten sonra boş
        Wait(() => Visible("PasswordTextInput") && ById("PasswordTextInput").AsTextBox().Text == string.Empty, "parola temizlendi");
        Click("TogglePasswordButton");

        // Yanlış parola.
        Unlock("yanlis-parola-1");
        Wait(() => Text("ErrorText") == "Geçersiz parola veya bozuk kasa dosyası.", "yanlış parola", 30);
        Assert.False(Visible("AddButton"));

        // Doğru parola -> dosyalar yerinde.
        Unlock(Pw);
        WaitDashboard();
        Wait(() => ItemNames().SequenceEqual(["şifre-notları.md"]), "kalıcı liste");

        // Yeniden başlatma: son kasa hatırlanır, açma modunda gelir; kilit süresi hatırlanır.
        CloseApp();
        Launch();
        Wait(() => ById("VaultPathInput").AsTextBox().Text == VaultDir, "son kasa hatırlandı");
        Assert.Equal("Kasa Aç", ById("SubmitButton").Name);
        Unlock(Pw);
        WaitDashboard();
        Assert.Equal("15", ById("AutoLockCombo").AsComboBox().SelectedItem?.Name);
        var settings = JsonDocument.Parse(File.ReadAllText(Path.Combine(DataDir, "settings.json"))).RootElement;
        Assert.Equal(VaultDir, settings.GetProperty("LastVaultPath").GetString());
    }

    [Fact]
    public void Existing_vault_checks_and_auto_lock()
    {
        Directory.CreateDirectory(VaultDir);
        Launch(autoLockSeconds: 4);

        // Kasa olmayan klasörü açma ve var olan kasanın üzerine oluşturma reddedilir.
        Click("ToggleModeButton"); // -> Kasa Aç
        ById("VaultPathInput").AsTextBox().Text = VaultDir;
        Unlock(Pw);
        Wait(() => Text("ErrorText") == "Seçilen klasörde geçerli bir kasa bulunamadı.", "kasa yok hatası");

        Click("ToggleModeButton"); // -> oluştur
        Unlock(Pw);
        WaitDashboard();

        // Otomatik kilit: 4 sn hareketsizlik -> giriş ekranı + neden.
        Wait(() => Visible("SubmitButton"), "otomatik kilit", 20);
        Wait(() => Text("InfoText").Contains("otomatik kilitlendi"), "kilit nedeni");

        Click("ToggleModeButton"); // -> oluştur (aynı klasör)
        Unlock(Pw);
        Wait(() => Text("ErrorText") == "Bu klasörde zaten bir kasa bulunuyor.", "üzerine oluşturma reddi", 30);
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [Fact]
    public void Keyboard_shortcuts()
    {
        Launch();
        ById("VaultPathInput").AsTextBox().Text = VaultDir;
        SetPassword(Pw);

        // Gerçek klavye girdisi: ortak masaüstü kilidi içinde, yalnız bu blok boyunca.
        using (GuiLock.Acquire())
        {
            _window.SetForeground();
            Wait(() => GetForegroundWindow() == _window.Properties.NativeWindowHandle.Value, "pencere ön planda");
            ById("PasswordInput").Focus();
            Keyboard.Type(VirtualKeyShort.RETURN); // Enter: kasayı oluştur/aç
            WaitDashboard();
        }

        // Dosya ekleme diyaloğu UIA ile (gerçek girdi gerekmez).
        Click("AddButton");
        CompleteFileDialog(Src("alfa.txt", "a"));
        Click("AddButton");
        CompleteFileDialog(Src("beta.txt", "b"));
        Wait(() => Items().Length == 2, "iki dosya");

        using (GuiLock.Acquire())
        {
            _window.SetForeground();
            Wait(() => GetForegroundWindow() == _window.Properties.NativeWindowHandle.Value, "pencere ön planda");

            // Ctrl+F arama, Esc temizler.
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_F);
            Keyboard.Type("beta");
            Wait(() => ItemNames().SequenceEqual(["beta.txt"]), "Ctrl+F ile arama");
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Wait(() => Items().Length == 2, "Esc aramayı temizler");

            // Aramadan aşağı ok -> liste; Enter -> çıkar onayı; Esc kapatır.
            Keyboard.Type(VirtualKeyShort.DOWN);
            Wait(() => Items()[0].IsSelected, "ok tuşu dosya seçer");
            Keyboard.Type(VirtualKeyShort.RETURN);
            Wait(() => Visible("ConfirmExportButton"), "Enter çıkar onayı");
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Wait(() => !Visible("ConfirmExportButton"), "Esc onayı kapatır");

            // Delete -> onay kutusu (Hayır UIA ile).
            Keyboard.Type(VirtualKeyShort.DELETE);
            Dialog();
        }
        AnswerMessageBox("7");
        Assert.Equal(2, Items().Length);

        using (GuiLock.Acquire())
        {
            _window.SetForeground();
            Wait(() => GetForegroundWindow() == _window.Properties.NativeWindowHandle.Value, "pencere ön planda");
            // Ctrl+O -> ekleme diyaloğu.
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_O);
            Dialog();
        }
        CancelDialog();

        using (GuiLock.Acquire())
        {
            _window.SetForeground();
            Wait(() => GetForegroundWindow() == _window.Properties.NativeWindowHandle.Value, "pencere ön planda");
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_L);
            WaitLogin();
        }
        Assert.Equal("Kasa kilitlendi.", Text("InfoText"));
    }
}

/// <summary>Repo kökündeki .gui.lock: agent'lar masaüstünü paylaşır; gerçek girdi yalnızca kilit içinde.</summary>
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
