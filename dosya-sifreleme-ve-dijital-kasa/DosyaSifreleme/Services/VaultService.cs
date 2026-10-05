using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using DosyaSifreleme.Models;
using Microsoft.Data.Sqlite;

namespace DosyaSifreleme.Services;

public class VaultService
{
    private readonly CryptographyService _crypto;
    private string? _activeVaultPath;
    private byte[]? _activeKey;
    private byte[]? _activeSalt;

    public bool IsOpen => _activeVaultPath != null && _activeKey != null;
    public string? ActiveVaultPath => _activeVaultPath;

    public VaultService(CryptographyService crypto) => _crypto = crypto;

    // Pooling kapalı: bağlantı kapanınca vault.db serbest kalır (kasa klasörü taşınabilir/silinebilir).
    private static SqliteConnection OpenDb(string vaultPath)
    {
        var conn = new SqliteConnection($"Data Source={Path.Combine(vaultPath, "vault.db")};Pooling=False");
        conn.Open();
        return conn;
    }

    public void CreateVault(string vaultPath, string password)
    {
        if (File.Exists(Path.Combine(vaultPath, "vault.db")))
            throw new InvalidOperationException("Bu klasörde zaten bir kasa bulunuyor.");

        Directory.CreateDirectory(vaultPath);
        Directory.CreateDirectory(Path.Combine(vaultPath, "data"));

        var salt = _crypto.GenerateRandomBytes(16);
        var key = _crypto.DeriveKey(password, salt);
        var verificationToken = _crypto.EncryptText("VERIFIED", key, salt);

        using var conn = OpenDb(vaultPath);
        using var tx = conn.BeginTransaction();
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = """
                CREATE TABLE IF NOT EXISTS VaultSettings (Key TEXT PRIMARY KEY, Value TEXT);
                CREATE TABLE IF NOT EXISTS VaultFiles (
                    Id TEXT PRIMARY KEY,
                    EncryptedName TEXT,
                    SizeBytes INTEGER,
                    EncryptedExtension TEXT,
                    DateAdded TEXT
                );
                INSERT INTO VaultSettings (Key, Value) VALUES ('Salt', @salt);
                INSERT INTO VaultSettings (Key, Value) VALUES ('Verification', @ver);
                """;
            cmd.Parameters.AddWithValue("@salt", Convert.ToBase64String(salt));
            cmd.Parameters.AddWithValue("@ver", verificationToken);
            cmd.ExecuteNonQuery();
        }
        tx.Commit();

        _activeVaultPath = vaultPath;
        _activeKey = key;
        _activeSalt = salt;
    }

    public bool OpenVault(string vaultPath, string password)
    {
        var dbPath = Path.Combine(vaultPath, "vault.db");
        if (!File.Exists(dbPath))
            throw new FileNotFoundException("Kasa veritabanı bulunamadı.");

        string saltBase64 = string.Empty;
        string verificationToken = string.Empty;

        using (var conn = OpenDb(vaultPath))
        {
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT Key, Value FROM VaultSettings";
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                var key = reader.GetString(0);
                var val = reader.GetString(1);
                if (key == "Salt") saltBase64 = val;
                else if (key == "Verification") verificationToken = val;
            }
        }

        if (string.IsNullOrEmpty(saltBase64) || string.IsNullOrEmpty(verificationToken))
            throw new CryptographicException("Geçersiz kasa dosyası veya bozuk ayarlar.");

        byte[] salt;
        try { salt = Convert.FromBase64String(saltBase64); }
        catch (FormatException) { throw new CryptographicException("Geçersiz kasa dosyası veya bozuk ayarlar."); }

        var derivedKey = _crypto.DeriveKey(password, salt);

        try
        {
            if (_crypto.DecryptText(verificationToken, password, derivedKey) == "VERIFIED")
            {
                _activeVaultPath = vaultPath;
                _activeKey = derivedKey;
                _activeSalt = salt;
                return true;
            }
        }
        catch (CryptographicException) { }
        catch (FormatException) { }

        CryptographicOperations.ZeroMemory(derivedKey);
        return false;
    }

    public void CloseVault()
    {
        if (_activeKey != null)
            CryptographicOperations.ZeroMemory(_activeKey);

        _activeVaultPath = null;
        _activeKey = null;
        _activeSalt = null;
    }

    public List<VaultFileItem> GetFiles()
    {
        if (!IsOpen) throw new InvalidOperationException("Kasa açık değil.");

        var files = new List<VaultFileItem>();
        using var conn = OpenDb(_activeVaultPath!);
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Id, EncryptedName, SizeBytes, EncryptedExtension, DateAdded FROM VaultFiles ORDER BY rowid";
        using var reader = cmd.ExecuteReader();

        while (reader.Read())
        {
            try
            {
                files.Add(new VaultFileItem
                {
                    Id = reader.GetString(0),
                    FileName = _crypto.DecryptText(reader.GetString(1), string.Empty, _activeKey),
                    SizeBytes = reader.GetInt64(2),
                    Extension = _crypto.DecryptText(reader.GetString(3), string.Empty, _activeKey),
                    DateAdded = DateTime.Parse(reader.GetString(4), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind)
                });
            }
            catch (Exception ex) when (ex is CryptographicException or FormatException) { }
        }

        return files;
    }

    // Şifreler, diske yazılan .enc dosyasını geri okuyup deşifre ederek orijinalle karşılaştırır;
    // ancak doğrulama geçerse kaydı ekler. Hata olursa .enc silinir, kasa tutarlı kalır.
    public void AddFile(string sourceFilePath)
    {
        if (!IsOpen) throw new InvalidOperationException("Kasa açık değil.");

        // Arka planda çalışır: kasa bu sırada kilitlenip anahtar sıfırlanırsa bu kopya etkilenmez.
        var vaultPath = _activeVaultPath!;
        var key = (byte[])_activeKey!.Clone();
        var salt = _activeSalt!;
        var id = Guid.NewGuid().ToString();
        var encryptedFilePath = Path.Combine(vaultPath, "data", $"{id}.enc");

        byte[] plaintext;
        try { plaintext = File.ReadAllBytes(sourceFilePath); }
        catch { CryptographicOperations.ZeroMemory(key); throw; }
        try
        {
            _crypto.EncryptToFile(plaintext, encryptedFilePath, key, salt);

            byte[] check = _crypto.DecryptFileToBytes(encryptedFilePath, key);
            try
            {
                if (!check.AsSpan().SequenceEqual(plaintext))
                    throw new CryptographicException("Şifreli kopya doğrulanamadı.");
            }
            finally { CryptographicOperations.ZeroMemory(check); }

            using var conn = OpenDb(vaultPath);
            using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                INSERT INTO VaultFiles (Id, EncryptedName, SizeBytes, EncryptedExtension, DateAdded)
                VALUES (@id, @name, @size, @ext, @date);
                """;
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@name", _crypto.EncryptText(Path.GetFileName(sourceFilePath), key, salt));
            cmd.Parameters.AddWithValue("@size", (long)plaintext.Length);
            cmd.Parameters.AddWithValue("@ext", _crypto.EncryptText(Path.GetExtension(sourceFilePath), key, salt));
            cmd.Parameters.AddWithValue("@date", DateTime.Now.ToString("o", CultureInfo.InvariantCulture));
            cmd.ExecuteNonQuery();
        }
        catch
        {
            CryptographyService.TryDelete(encryptedFilePath);
            throw;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(plaintext);
            CryptographicOperations.ZeroMemory(key);
        }
    }

    // Kasaya taşı: önce AddFile (şifrele + geri okuyup doğrula), sonra orijinal sıfırlarla üzerine yazılıp silinir.
    // Dosya bu arada değiştiyse orijinale dokunulmaz.
    // ponytail: tek geçiş üzerine yazma; SSD/kopyalayan dosya sistemlerinde eski blokların kalmadığı garanti edilemez.
    public void MoveFileIntoVault(string sourceFilePath)
    {
        var before = new FileInfo(sourceFilePath);
        long length = before.Length;
        var stamp = before.LastWriteTimeUtc;

        AddFile(sourceFilePath);

        var after = new FileInfo(sourceFilePath);
        if (after.Length != length || after.LastWriteTimeUtc != stamp)
            throw new IOException("Dosya şifrelenirken değişti; şifreli kopya eklendi ancak orijinal silinmedi.");

        using (var fs = new FileStream(sourceFilePath, FileMode.Open, FileAccess.Write, FileShare.None))
        {
            var zeros = new byte[81920];
            for (long done = 0; done < length; done += zeros.Length)
                fs.Write(zeros, 0, (int)Math.Min(zeros.Length, length - done));
            fs.Flush(flushToDisk: true);
        }
        File.Delete(sourceFilePath);
    }

    public void ExportFile(VaultFileItem fileItem, string destinationPath)
    {
        if (!IsOpen) throw new InvalidOperationException("Kasa açık değil.");

        var encryptedFilePath = Path.Combine(_activeVaultPath!, "data", $"{fileItem.Id}.enc");
        if (!File.Exists(encryptedFilePath))
            throw new FileNotFoundException("Şifreli veri dosyası bulunamadı.");

        // Arka planda çalışır; kasa bu sırada kilitlenip anahtar sıfırlanırsa kopya etkilenmez.
        var key = (byte[])_activeKey!.Clone();
        try { _crypto.DecryptFile(encryptedFilePath, destinationPath, key); }
        finally { CryptographicOperations.ZeroMemory(key); }
    }

    // Tümünü çıkar (yedek): her dosya klasöre deşifre edilir; aynı ad varsa "ad (2).uzantı" ile, üzerine yazılmaz.
    public int ExportAll(string folder)
    {
        Directory.CreateDirectory(folder);
        var count = 0;
        foreach (var item in GetFiles())
        {
            ExportFile(item, UniquePath(folder, item.FileName));
            count++;
        }
        return count;
    }

    internal static string UniquePath(string folder, string fileName)
    {
        var name = Path.GetFileName(fileName);
        if (string.IsNullOrWhiteSpace(name)) name = "dosya";
        var path = Path.Combine(folder, name);
        var stem = Path.GetFileNameWithoutExtension(name);
        var ext = Path.GetExtension(name);
        for (var i = 2; File.Exists(path); i++)
            path = Path.Combine(folder, $"{stem} ({i}){ext}");
        return path;
    }

    public void DeleteFile(VaultFileItem fileItem)
    {
        if (!IsOpen) throw new InvalidOperationException("Kasa açık değil.");

        // Önce kayıt: dosya silinemezse geriye zararsız bir yetim .enc kalır, kayıtsız-dosyasız liste öğesi değil.
        using (var conn = OpenDb(_activeVaultPath!))
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "DELETE FROM VaultFiles WHERE Id = @id";
            cmd.Parameters.AddWithValue("@id", fileItem.Id);
            cmd.ExecuteNonQuery();
        }

        var encryptedFilePath = Path.Combine(_activeVaultPath!, "data", $"{fileItem.Id}.enc");
        if (File.Exists(encryptedFilePath))
            File.Delete(encryptedFilePath);
    }
}
