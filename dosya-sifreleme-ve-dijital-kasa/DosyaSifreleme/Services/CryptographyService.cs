using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using Konscious.Security.Cryptography;

namespace DosyaSifreleme.Services
{
    public class CryptographyService
    {
        private const int SaltSize = 16;
        private const int NonceSize = 12; // IV for GCM
        private const int TagSize = 16;   // Auth tag for GCM
        private const int HeaderSize = SaltSize + NonceSize + TagSize;

        // Derived Key settings (Argon2id OWASP compliant).
        // Kasada saklanmaz: değiştirilirse mevcut kasalar açılamaz.
        private const int ArgonIterations = 4;
        private const int ArgonMemorySize = 65536; // 64 MB
        private const int ArgonParallelism = 2;

        public byte[] DeriveKey(string password, byte[] salt)
        {
            using (var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password)))
            {
                argon2.Salt = salt;
                argon2.DegreeOfParallelism = ArgonParallelism;
                argon2.Iterations = ArgonIterations;
                argon2.MemorySize = ArgonMemorySize;

                return argon2.GetBytes(32); // 256-bit key
            }
        }

        public byte[] GenerateRandomBytes(int size)
        {
            byte[] bytes = new byte[size];
            RandomNumberGenerator.Fill(bytes);
            return bytes;
        }

        // Dosya biçimi (değişmedi, eski kasalar okunur): Salt (16B) + Nonce (12B) + Tag (16B) + Ciphertext.
        // Her dosyada yeni rastgele nonce üretilir (aynı anahtarla nonce tekrarı GCM'yi kırar);
        // tag bütünlüğü doğrular: yanlış anahtar veya değiştirilmiş dosya deşifrede reddedilir.
        public void EncryptToFile(byte[] plaintext, string outputFilePath, byte[] derivedKey, byte[] salt)
        {
            byte[] nonce = GenerateRandomBytes(NonceSize);
            byte[] tag = new byte[TagSize];
            byte[] ciphertext = new byte[plaintext.Length];

            using (var aesGcm = new AesGcm(derivedKey, TagSize))
            {
                aesGcm.Encrypt(nonce, plaintext, ciphertext, tag);
            }

            try
            {
                using var fs = new FileStream(outputFilePath, FileMode.CreateNew, FileAccess.Write);
                fs.Write(salt);
                fs.Write(nonce);
                fs.Write(tag);
                fs.Write(ciphertext);
                fs.Flush(flushToDisk: true);
            }
            catch
            {
                TryDelete(outputFilePath); // yarım şifreli dosya bırakma
                throw;
            }
        }

        // Şifreli dosyayı verilen anahtarla belleğe deşifre eder. Çağıran, işi bitince
        // CryptographicOperations.ZeroMemory ile düz metni temizlemelidir.
        public byte[] DecryptFileToBytes(string inputFilePath, byte[] key)
        {
            using var fs = new FileStream(inputFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            if (fs.Length < HeaderSize)
                throw new CryptographicException("Geçersiz veya bozuk şifreli dosya.");

            byte[] salt = new byte[SaltSize];
            byte[] nonce = new byte[NonceSize];
            byte[] tag = new byte[TagSize];
            fs.ReadExactly(salt);
            fs.ReadExactly(nonce);
            fs.ReadExactly(tag);

            byte[] ciphertext = new byte[fs.Length - HeaderSize];
            fs.ReadExactly(ciphertext);
            byte[] plaintext = new byte[ciphertext.Length];

            try
            {
                using var aesGcm = new AesGcm(key, TagSize);
                aesGcm.Decrypt(nonce, ciphertext, tag, plaintext);
            }
            catch (AuthenticationTagMismatchException)
            {
                throw new CryptographicException("Dosya doğrulanamadı: parola yanlış ya da dosya bozulmuş/değiştirilmiş.");
            }

            return plaintext;
        }

        // Önce tamamı bellekte doğrulanır; yanlış anahtar/bozuk dosyada hedefe hiçbir şey yazılmaz.
        // Yazma hatasında yarım düz metin bırakılmaz (geçici dosya silinir, var olan hedef el değmeden kalır).
        public void DecryptFile(string inputFilePath, string outputFilePath, byte[] key)
        {
            byte[] plaintext = DecryptFileToBytes(inputFilePath, key);
            var dir = Path.GetDirectoryName(Path.GetFullPath(outputFilePath))!;
            var tmp = Path.Combine(dir, $".{Guid.NewGuid():N}.dk-tmp");
            try
            {
                using (var fs = new FileStream(tmp, FileMode.CreateNew, FileAccess.Write))
                {
                    fs.Write(plaintext);
                    fs.Flush(flushToDisk: true);
                }
                File.Move(tmp, outputFilePath, overwrite: true);
            }
            catch
            {
                TryDelete(tmp);
                throw;
            }
            finally
            {
                CryptographicOperations.ZeroMemory(plaintext);
            }
        }

        internal static void TryDelete(string path)
        {
            try { File.Delete(path); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }

        public string EncryptText(string plainText, byte[] derivedKey, byte[] salt)
        {
            byte[] nonce = GenerateRandomBytes(NonceSize);
            byte[] tag = new byte[TagSize];
            byte[] plaintextBytes = Encoding.UTF8.GetBytes(plainText);
            byte[] ciphertextBytes = new byte[plaintextBytes.Length];

            using (var aesGcm = new AesGcm(derivedKey, TagSize))
            {
                aesGcm.Encrypt(nonce, plaintextBytes, ciphertextBytes, tag);
            }

            // Package metadata: salt + nonce + tag + ciphertext
            byte[] result = new byte[HeaderSize + ciphertextBytes.Length];
            Buffer.BlockCopy(salt, 0, result, 0, SaltSize);
            Buffer.BlockCopy(nonce, 0, result, SaltSize, NonceSize);
            Buffer.BlockCopy(tag, 0, result, SaltSize + NonceSize, TagSize);
            Buffer.BlockCopy(ciphertextBytes, 0, result, HeaderSize, ciphertextBytes.Length);

            return Convert.ToBase64String(result);
        }

        // knownKey: kasadaki tüm kayıtlar aynı tuzla şifrelendiği için açık kasanın anahtarı verilebilir;
        // böylece her alan için yeniden Argon2 (64 MB, yavaş) çalışmaz. Yanlış anahtar GCM etiketinde reddedilir.
        public string DecryptText(string encryptedTextBase64, string password, byte[]? knownKey = null)
        {
            byte[] encryptedBytes = Convert.FromBase64String(encryptedTextBase64);
            if (encryptedBytes.Length < HeaderSize)
            {
                throw new CryptographicException("Geçersiz şifreli metin.");
            }

            byte[] salt = new byte[SaltSize];
            byte[] nonce = new byte[NonceSize];
            byte[] tag = new byte[TagSize];

            Buffer.BlockCopy(encryptedBytes, 0, salt, 0, SaltSize);
            Buffer.BlockCopy(encryptedBytes, SaltSize, nonce, 0, NonceSize);
            Buffer.BlockCopy(encryptedBytes, SaltSize + NonceSize, tag, 0, TagSize);

            int ciphertextLength = encryptedBytes.Length - HeaderSize;
            byte[] ciphertext = new byte[ciphertextLength];
            Buffer.BlockCopy(encryptedBytes, HeaderSize, ciphertext, 0, ciphertextLength);

            byte[] key = knownKey ?? DeriveKey(password, salt);
            byte[] plaintext = new byte[ciphertextLength];

            using (var aesGcm = new AesGcm(key, TagSize))
            {
                aesGcm.Decrypt(nonce, ciphertext, tag, plaintext);
            }

            return Encoding.UTF8.GetString(plaintext);
        }
    }
}
