using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace ClipboardYoneticisi.Services
{
    public class EncryptionService
    {
        private static EncryptionService? _instance;
        public static EncryptionService Instance => _instance ??= new EncryptionService();

        private readonly string _metaPath;
        private byte[]? _key;

        private EncryptionService()
        {
            AppPaths.EnsureDirectories();
            _metaPath = AppPaths.EncryptionMetaPath;
        }

        public bool IsEnabled => SettingsService.Instance.Settings.EnableEncryption;
        public bool IsUnlocked => !IsEnabled || _key != null;

        public bool HasPassword => File.Exists(_metaPath);

        public bool SetupPassword(string password)
        {
            var salt = RandomNumberGenerator.GetBytes(16);
            _key = DeriveKey(password, salt);
            var meta = new EncryptionMeta
            {
                Salt = Convert.ToBase64String(salt),
                Verifier = ComputeVerifier(_key)
            };
            File.WriteAllText(_metaPath, JsonSerializer.Serialize(meta));
            return true;
        }

        public bool Unlock(string password)
        {
            if (!File.Exists(_metaPath))
                return false;

            try
            {
                var meta = JsonSerializer.Deserialize<EncryptionMeta>(File.ReadAllText(_metaPath));
                if (meta?.Salt == null || meta.Verifier == null)
                    return false;

                var salt = Convert.FromBase64String(meta.Salt);
                var key = DeriveKey(password, salt);
                if (ComputeVerifier(key) != meta.Verifier)
                    return false;

                _key = key;
                return true;
            }
            catch
            {
                return false;
            }
        }

        public void Lock() => _key = null;

        public void DisableEncryption()
        {
            _key = null;
            if (File.Exists(_metaPath))
                File.Delete(_metaPath);
        }

        // Sifreli mod: anahtar parola + rastgele salt'tan PBKDF2 (SHA256, 100k tur) ile turetilir,
        // sadece bellekte tutulur. encryption.meta yalnizca salt ve anahtarin SHA256 dogrulayicisini
        // saklar. Icerik AES-256 (her kayitta yeni IV) ile "ENC:" + base64(IV | sifreli) olarak yazilir.
        public string Encrypt(string plain)
        {
            if (!IsEnabled || _key == null)
                return plain;

            using var aes = Aes.Create();
            aes.Key = _key;
            aes.GenerateIV();
            using var encryptor = aes.CreateEncryptor();
            var plainBytes = Encoding.UTF8.GetBytes(plain);
            var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
            var combined = new byte[aes.IV.Length + cipherBytes.Length];
            Buffer.BlockCopy(aes.IV, 0, combined, 0, aes.IV.Length);
            Buffer.BlockCopy(cipherBytes, 0, combined, aes.IV.Length, cipherBytes.Length);
            return "ENC:" + Convert.ToBase64String(combined);
        }

        public string Decrypt(string stored)
        {
            if (!stored.StartsWith("ENC:", StringComparison.Ordinal) || _key == null)
                return stored;

            var combined = Convert.FromBase64String(stored[4..]);
            using var aes = Aes.Create();
            aes.Key = _key;
            var iv = new byte[16];
            var cipher = new byte[combined.Length - 16];
            Buffer.BlockCopy(combined, 0, iv, 0, 16);
            Buffer.BlockCopy(combined, 16, cipher, 0, cipher.Length);
            aes.IV = iv;
            using var decryptor = aes.CreateDecryptor();
            var plainBytes = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);
            return Encoding.UTF8.GetString(plainBytes);
        }

        public string DecryptIfNeeded(string stored)
        {
            if (!IsEnabled || !stored.StartsWith("ENC:", StringComparison.Ordinal))
                return stored;
            return IsUnlocked ? Decrypt(stored) : "🔒 Şifreli içerik";
        }

        private static byte[] DeriveKey(string password, byte[] salt)
        {
            return Rfc2898DeriveBytes.Pbkdf2(password, salt, 100_000, HashAlgorithmName.SHA256, 32);
        }

        private static string ComputeVerifier(byte[] key)
        {
            var hash = SHA256.HashData(key);
            return Convert.ToBase64String(hash);
        }

        private class EncryptionMeta
        {
            public string? Salt { get; set; }
            public string? Verifier { get; set; }
        }
    }
}
