using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class SettingsService
    {
        private const string ProtectedPrefix = "dpapi:";
        private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

        private readonly string _settingsPath;
        private readonly object _saveLock = new();
        private AppSettings _settings = new();

        public SettingsService(string dataFolder)
        {
            Directory.CreateDirectory(dataFolder);
            _settingsPath = Path.Combine(dataFolder, "settings.json");
            Load();
        }

        public AppSettings Current => _settings;

        public void Load()
        {
            if (!File.Exists(_settingsPath))
            {
                _settings = new AppSettings();
                return;
            }

            try
            {
                var json = File.ReadAllText(_settingsPath);
                _settings = JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
                _settings.SmtpPassword = Unprotect(_settings.SmtpPassword);
            }
            catch
            {
                _settings = new AppSettings();
            }
        }

        public void Save(AppSettings settings)
        {
            _settings = settings;
            // SMTP parolası düz metin yazılmaz (yedek zip'ine de girer): Windows DPAPI ile yalnızca bu kullanıcı çözebilir.
            var node = JsonSerializer.SerializeToNode(settings)!.AsObject();
            node[nameof(AppSettings.SmtpPassword)] = Protect(settings.SmtpPassword);
            var json = node.ToJsonString(JsonOptions);

            // Önce geçici dosyaya yaz, sonra değiştir: yazma yarıda kesilirse (çökme/kapanma) ayarlar sıfırlanmaz.
            lock (_saveLock)
            {
                var tmp = _settingsPath + ".tmp";
                File.WriteAllText(tmp, json);
                File.Move(tmp, _settingsPath, overwrite: true);
            }
        }

        internal static string? Protect(string? plain)
        {
            if (string.IsNullOrEmpty(plain)) return plain;
            var bytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(plain), null, DataProtectionScope.CurrentUser);
            return ProtectedPrefix + Convert.ToBase64String(bytes);
        }

        internal static string? Unprotect(string? stored)
        {
            // Eski sürümlerin düz metin parolası olduğu gibi okunur; bir sonraki kayıtta şifrelenir.
            if (string.IsNullOrEmpty(stored) || !stored.StartsWith(ProtectedPrefix, StringComparison.Ordinal))
                return stored;
            try
            {
                var bytes = ProtectedData.Unprotect(
                    Convert.FromBase64String(stored[ProtectedPrefix.Length..]), null, DataProtectionScope.CurrentUser);
                return Encoding.UTF8.GetString(bytes);
            }
            catch (Exception)
            {
                return null; // başka kullanıcı/bilgisayardan gelen yedek: parolanın yeniden girilmesi gerekir
            }
        }

        public void ApplyStartupSetting()
        {
            if (_settings.RunAtStartup)
            {
                // Her açılışta yeniden yaz: exe taşındıysa (ör. dist\ klasörüne) eski yol kalmasın.
                StartupService.SetEnabled(true);
            }
            else if (StartupService.IsEnabled())
            {
                StartupService.SetEnabled(false);
            }
        }
    }
}
