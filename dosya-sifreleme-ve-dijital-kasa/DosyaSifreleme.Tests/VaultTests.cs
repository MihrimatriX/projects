using System.IO;
using System.Diagnostics;
using System.Security.Cryptography;
using DosyaSifreleme.Models;
using DosyaSifreleme.Services;
using Xunit;

namespace DosyaSifreleme.Tests;

public class VaultTests : IDisposable
{
    private const string Pw = "dogru-parola-123";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "kasa-test-" + Guid.NewGuid().ToString("N"));
    private readonly CryptographyService _crypto = new();
    private string VaultDir => Path.Combine(_root, "kasa");
    private string OutDir => Directory.CreateDirectory(Path.Combine(_root, "out")).FullName;

    public VaultTests() => Directory.CreateDirectory(_root);

    public void Dispose()
    {
        try { Directory.Delete(_root, true); } catch (IOException) { }
    }

    private VaultService NewVault()
    {
        var v = new VaultService(_crypto);
        v.CreateVault(VaultDir, Pw);
        return v;
    }

    private string Source(string name, byte[] content)
    {
        var p = Path.Combine(_root, name);
        File.WriteAllBytes(p, content);
        return p;
    }

    private string[] EncFiles() => Directory.GetFiles(Path.Combine(VaultDir, "data"));

    [Fact]
    public void Create_then_reopen_with_right_password_and_reject_wrong_one()
    {
        NewVault().CloseVault();

        var v = new VaultService(_crypto);
        Assert.False(v.OpenVault(VaultDir, "yanlis-parola"));
        Assert.False(v.IsOpen);
        Assert.True(v.OpenVault(VaultDir, Pw));
        Assert.True(v.IsOpen);
    }

    [Fact]
    public void Creating_over_existing_vault_is_refused_and_keeps_it_usable()
    {
        NewVault().CloseVault();
        Assert.Throws<InvalidOperationException>(() => new VaultService(_crypto).CreateVault(VaultDir, "baska-parola"));
        Assert.True(new VaultService(_crypto).OpenVault(VaultDir, Pw));
    }

    [Fact]
    public void Add_list_export_roundtrip_without_plaintext_on_disk()
    {
        var v = NewVault();
        var content = RandomNumberGenerator.GetBytes(200_000);
        v.AddFile(Source("gizli rapor.pdf", content));

        var item = Assert.Single(v.GetFiles());
        Assert.Equal("gizli rapor.pdf", item.FileName);
        Assert.Equal(".pdf", item.Extension);
        Assert.Equal(content.Length, item.SizeBytes);

        // Kasada ad ve içerik düz metin olarak geçmez.
        var enc = File.ReadAllBytes(Assert.Single(EncFiles()));
        Assert.Equal(content.Length + 44, enc.Length);
        Assert.False(enc.AsSpan().IndexOf(content.AsSpan(0, 64)) >= 0);
        Assert.DoesNotContain("gizli rapor", File.ReadAllText(Path.Combine(VaultDir, "vault.db"), System.Text.Encoding.Latin1));

        var dest = Path.Combine(OutDir, "cikti.pdf");
        v.ExportFile(item, dest);
        Assert.Equal(content, File.ReadAllBytes(dest));
        Assert.Single(Directory.GetFiles(OutDir)); // geçici dosya kalmadı
    }

    [Fact]
    public void Files_survive_close_and_reopen()
    {
        var v = NewVault();
        v.AddFile(Source("a.txt", "merhaba"u8.ToArray()));
        v.CloseVault();
        Assert.Throws<InvalidOperationException>(() => v.GetFiles());

        Assert.True(v.OpenVault(VaultDir, Pw));
        var dest = Path.Combine(OutDir, "a.txt");
        v.ExportFile(Assert.Single(v.GetFiles()), dest);
        Assert.Equal("merhaba", File.ReadAllText(dest));
    }

    [Fact]
    public void Tampered_ciphertext_is_rejected_and_nothing_is_written()
    {
        var v = NewVault();
        v.AddFile(Source("b.bin", RandomNumberGenerator.GetBytes(1000)));
        var enc = Assert.Single(EncFiles());
        var bytes = File.ReadAllBytes(enc);
        bytes[^1] ^= 0x01;
        File.WriteAllBytes(enc, bytes);

        var dest = Path.Combine(OutDir, "b.bin");
        var ex = Assert.ThrowsAny<CryptographicException>(() => v.ExportFile(Assert.Single(v.GetFiles()), dest));
        Assert.Contains("doğrulanamadı", ex.Message);
        Assert.Empty(Directory.GetFiles(OutDir));
    }

    [Fact]
    public void Failed_export_leaves_existing_destination_untouched()
    {
        var v = NewVault();
        v.AddFile(Source("c.txt", "yeni"u8.ToArray()));
        File.WriteAllBytes(Assert.Single(EncFiles()), new byte[10]); // başlıktan kısa = bozuk

        var dest = Path.Combine(OutDir, "c.txt");
        File.WriteAllText(dest, "eski");
        Assert.ThrowsAny<CryptographicException>(() => v.ExportFile(Assert.Single(v.GetFiles()), dest));
        Assert.Equal("eski", File.ReadAllText(dest));
        Assert.Single(Directory.GetFiles(OutDir));
    }

    [Fact]
    public void Wrong_key_cannot_decrypt_file()
    {
        var path = Path.Combine(_root, "x.enc");
        _crypto.EncryptToFile("veri"u8.ToArray(), path, RandomNumberGenerator.GetBytes(32), RandomNumberGenerator.GetBytes(16));
        Assert.ThrowsAny<CryptographicException>(() => _crypto.DecryptFileToBytes(path, RandomNumberGenerator.GetBytes(32)));
    }

    [Fact]
    public void Same_content_twice_uses_fresh_nonce()
    {
        var key = RandomNumberGenerator.GetBytes(32);
        var salt = RandomNumberGenerator.GetBytes(16);
        var a = Path.Combine(_root, "1.enc");
        var b = Path.Combine(_root, "2.enc");
        _crypto.EncryptToFile("ayni"u8.ToArray(), a, key, salt);
        _crypto.EncryptToFile("ayni"u8.ToArray(), b, key, salt);
        Assert.NotEqual(File.ReadAllBytes(a), File.ReadAllBytes(b));
    }

    [Fact]
    public void Legacy_file_layout_still_decrypts()
    {
        // Eski sürümün yazdığı biçim: salt(16) | nonce(12) | tag(16) | ciphertext — elle üretilir.
        var key = RandomNumberGenerator.GetBytes(32);
        var salt = RandomNumberGenerator.GetBytes(16);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var plain = "eski kasa verisi"u8.ToArray();
        var ct = new byte[plain.Length];
        var tag = new byte[16];
        using (var gcm = new AesGcm(key, 16)) gcm.Encrypt(nonce, plain, ct, tag);
        var path = Path.Combine(_root, "legacy.enc");
        File.WriteAllBytes(path, [.. salt, .. nonce, .. tag, .. ct]);

        Assert.Equal(plain, _crypto.DecryptFileToBytes(path, key));
    }

    [Fact]
    public void Failed_add_leaves_no_encrypted_leftovers_or_rows()
    {
        var v = NewVault();
        Assert.ThrowsAny<IOException>(() => v.AddFile(Path.Combine(_root, "yok.txt")));

        var locked = Source("kilitli.txt", "x"u8.ToArray());
        using (new FileStream(locked, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
            Assert.ThrowsAny<IOException>(() => v.AddFile(locked));

        Assert.Empty(EncFiles());
        Assert.Empty(v.GetFiles());
    }

    [Fact]
    public void Move_into_vault_deletes_original_only_after_verified_copy()
    {
        var v = NewVault();
        var content = RandomNumberGenerator.GetBytes(300_000);
        var src = Source("tasi.bin", content);

        v.MoveFileIntoVault(src);

        Assert.False(File.Exists(src));
        var dest = Path.Combine(OutDir, "tasi.bin");
        v.ExportFile(Assert.Single(v.GetFiles()), dest);
        Assert.Equal(content, File.ReadAllBytes(dest));
    }

    [Fact]
    public void Move_keeps_original_when_encryption_fails()
    {
        var v = NewVault();
        var src = Source("kalsin.txt", "onemli"u8.ToArray());
        Directory.Delete(Path.Combine(VaultDir, "data")); // şifreli kopya yazılamaz

        Assert.ThrowsAny<IOException>(() => v.MoveFileIntoVault(src));
        Assert.Equal("onemli", File.ReadAllText(src));
        Assert.Empty(v.GetFiles());
    }

    [Fact]
    public void Delete_removes_record_and_ciphertext()
    {
        var v = NewVault();
        v.AddFile(Source("d.txt", "sil"u8.ToArray()));
        v.AddFile(Source("e.txt", "kalsin"u8.ToArray()));

        v.DeleteFile(v.GetFiles().Single(f => f.FileName == "d.txt"));

        Assert.Equal("e.txt", Assert.Single(v.GetFiles()).FileName);
        Assert.Single(EncFiles());
    }

    [Fact]
    public void Vault_folder_is_not_locked_after_close()
    {
        var v = NewVault();
        v.AddFile(Source("f.txt", "x"u8.ToArray()));
        v.GetFiles();
        v.CloseVault();
        Directory.Move(VaultDir, VaultDir + "-tasindi"); // açık SQLite tutamağı kalsaydı başarısız olurdu
    }

    [Fact]
    public void Kdf_parameters_are_frozen_for_existing_vaults()
    {
        // Argon2id parametreleri kasada saklanmaz: değişirse eski kasalar açılamaz. Bu çıktı sabit kalmalı.
        var key = _crypto.DeriveKey("kasa-parolasi", new byte[16]);
        Assert.Equal("0FA88111717936E7FDE222E344F522298C5199A61D2075AC8EC9887838ADCB85", Convert.ToHexString(key));
    }

    [Fact]
    public void Export_all_writes_every_file_without_overwriting()
    {
        var v = NewVault();
        v.AddFile(Source("not.txt", "bir"u8.ToArray()));
        Directory.CreateDirectory(Path.Combine(_root, "alt"));
        File.WriteAllBytes(Path.Combine(_root, "alt", "not.txt"), "iki"u8.ToArray());
        v.AddFile(Path.Combine(_root, "alt", "not.txt"));
        File.WriteAllText(Path.Combine(OutDir, "not.txt"), "mevcut");

        Assert.Equal(2, v.ExportAll(OutDir));

        Assert.Equal("mevcut", File.ReadAllText(Path.Combine(OutDir, "not.txt")));
        Assert.Equal(["bir", "iki"], new[] { "not (2).txt", "not (3).txt" }
            .Select(n => File.ReadAllText(Path.Combine(OutDir, n))).Order());
    }

    [Fact]
    public void DisplaySize_formats_units()
    {
        Assert.Equal("512 B", new VaultFileItem { SizeBytes = 512 }.DisplaySize);
        Assert.Equal("2 KB", new VaultFileItem { SizeBytes = 2048 }.DisplaySize);
        Assert.Equal("1.5 MB", new VaultFileItem { SizeBytes = 1572864 }.DisplaySize.Replace(',', '.'));
    }
}

public class StartupSmokeTests
{
    [Fact]
    public void App_starts_and_stays_running()
    {
        // Kullanıcının açık bir örneği varsa karışmamak için atla.
        if (Process.GetProcessesByName("DosyaSifreleme").Length > 0)
            return;

        var exe = Path.Combine(AppContext.BaseDirectory, "DosyaSifreleme.exe");
        Assert.True(File.Exists(exe), $"exe yok: {exe}");

        // Uygulama açılışta diske yazmaz (kasa klasörünü kullanıcı seçer); yalnızca giriş ekranı açılır.
        // Ayarlar gerçek %LOCALAPPDATA% yerine geçici klasörden okunur.
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false };
        psi.Environment["DOSYA_SIFRELEME_DATA_DIR"] = Path.Combine(Path.GetTempPath(), "kasa-smoke-" + Guid.NewGuid().ToString("N"));
        using var proc = Process.Start(psi)!;
        try
        {
            Assert.False(proc.WaitForExit(5000), "Uygulama erken kapandi");
        }
        finally
        {
            if (!proc.HasExited) { proc.Kill(entireProcessTree: true); proc.WaitForExit(5000); }
        }
    }
}

public class AppSettingsTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "kasa-ayar-" + Guid.NewGuid().ToString("N"));

    public AppSettingsTests() => Environment.SetEnvironmentVariable("DOSYA_SIFRELEME_DATA_DIR", _dir);

    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DOSYA_SIFRELEME_DATA_DIR", null);
        try { Directory.Delete(_dir, true); } catch (IOException) { }
    }

    [Fact]
    public void Settings_roundtrip_and_fall_back_on_bad_values()
    {
        Assert.Equal(5, AppSettings.Load().AutoLockMinutes); // dosya yok: varsayılan

        new AppSettings { LastVaultPath = @"D:\Kasam", AutoLockMinutes = 15 }.Save();
        var s = AppSettings.Load();
        Assert.Equal(@"D:\Kasam", s.LastVaultPath);
        Assert.Equal(900, s.AutoLockSeconds);
        Assert.DoesNotContain("parola", File.ReadAllText(Path.Combine(_dir, "settings.json")), StringComparison.OrdinalIgnoreCase);

        File.WriteAllText(Path.Combine(_dir, "settings.json"), "{\"AutoLockMinutes\": 7}");
        Assert.Equal(5, AppSettings.Load().AutoLockMinutes); // listede olmayan değer
        File.WriteAllText(Path.Combine(_dir, "settings.json"), "bozuk{");
        Assert.Equal(string.Empty, AppSettings.Load().LastVaultPath);
    }
}
