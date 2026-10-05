using System;
using System.IO;

namespace ClipboardYoneticisi.Services
{
    public static class AppPaths
    {
        public const string AppFolderName = "ClipboardGecmisiYoneticisi";

        // CLIPBOARD_GECMISI_DATA_DIR: testler ve duman testi gercek kullanici verisine dokunmasin diye.
        public static string DataFolder { get; } =
            Environment.GetEnvironmentVariable("CLIPBOARD_GECMISI_DATA_DIR") is { Length: > 0 } overrideDir
                ? overrideDir
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppFolderName);

        /// <summary>Veri klasoru ortam degiskeniyle degistirildi (test/duman): kayit defterine ve tek-ornek kilidine dokunulmaz.</summary>
        public static bool IsDataDirOverridden { get; } =
            Environment.GetEnvironmentVariable("CLIPBOARD_GECMISI_DATA_DIR") is { Length: > 0 };

        /// <summary>
        /// CLIPBOARD_GECMISI_TEST=1 (UI testleri): yalnizca test isaretli pano icerigi kaydedilir, uygulamanin
        /// yazdiklari isaretlenir. Paylasilan masaustunde baska sureclerin pano trafigi testi bozmaz;
        /// kullanicinin gercek ornegi de test verisini kaydetmez.
        /// </summary>
        public static bool IsTestMode { get; } =
            Environment.GetEnvironmentVariable("CLIPBOARD_GECMISI_TEST") == "1";

        public static string DbPath => Path.Combine(DataFolder, "clipboard.db");
        public static string SettingsPath => Path.Combine(DataFolder, "settings.json");
        public static string ImagesFolder => Path.Combine(DataFolder, "images");
        public static string LogsFolder => Path.Combine(DataFolder, "logs");
        public static string EncryptionMetaPath => Path.Combine(DataFolder, "encryption.meta");

        public static void EnsureDirectories()
        {
            Directory.CreateDirectory(DataFolder);
            Directory.CreateDirectory(ImagesFolder);
            Directory.CreateDirectory(LogsFolder);
        }

        public static void MigrateLegacyDataIfNeeded()
        {
            var legacyFolder = Path.Combine(AppContext.BaseDirectory, "data");
            if (!Directory.Exists(legacyFolder))
                return;

            if (File.Exists(DbPath))
                return;

            EnsureDirectories();
            CopyDirectory(legacyFolder, DataFolder);
            LogService.Info("Legacy data migrated to AppData.");
        }

        private static void CopyDirectory(string source, string target)
        {
            foreach (var dir in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(source, dir);
                Directory.CreateDirectory(Path.Combine(target, relative));
            }

            foreach (var file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(source, file);
                var dest = Path.Combine(target, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
                File.Copy(file, dest, overwrite: true);
            }
        }
    }
}
