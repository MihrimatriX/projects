using System;
using System.IO;
using System.IO.Compression;

namespace EkranZamani.Services
{
    public class BackupService
    {
        private readonly DatabaseService _db;
        private readonly SettingsService _settings;

        public BackupService(DatabaseService db, SettingsService settings)
        {
            _db = db;
            _settings = settings;
        }

        public string CreateBackupZip()
        {
            var downloads = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads");
            Directory.CreateDirectory(downloads);

            var zipPath = Path.Combine(downloads, $"ekran-zamani-yedek-{DateTime.Now:yyyyMMdd-HHmmss}.zip");
            if (File.Exists(zipPath))
                File.Delete(zipPath);

            _settings.Save(_settings.Current);
            // Havuzdaki açık SQLite bağlantıları usage.db'yi kilitler; kopyalamadan önce kapat.
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();

            using (var archive = ZipFile.Open(zipPath, ZipArchiveMode.Create))
            {
                AddFileIfExists(archive, Path.Combine(_db.DataFolder, "usage.db"));
                AddFileIfExists(archive, Path.Combine(_db.DataFolder, "settings.json"));
            }

            return zipPath;
        }

        public void RestoreFromZip(string zipPath)
        {
            if (!File.Exists(zipPath))
                throw new FileNotFoundException("Yedek dosyası bulunamadı.", zipPath);

            Directory.CreateDirectory(_db.DataFolder);
            var tempDir = Path.Combine(Path.GetTempPath(), "EkranZamani_restore_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                ZipFile.ExtractToDirectory(zipPath, tempDir, overwriteFiles: true);
                Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();

                CopyIfExists(Path.Combine(tempDir, "usage.db"), Path.Combine(_db.DataFolder, "usage.db"));
                CopyIfExists(Path.Combine(tempDir, "settings.json"), Path.Combine(_db.DataFolder, "settings.json"));

                _settings.Load();
            }
            finally
            {
                try { Directory.Delete(tempDir, recursive: true); }
                catch { /* best effort */ }
            }
        }

        public void OpenDataFolder()
        {
            Directory.CreateDirectory(_db.DataFolder);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = _db.DataFolder,
                UseShellExecute = true
            });
        }

        private static void AddFileIfExists(ZipArchive archive, string path)
        {
            if (!File.Exists(path)) return;
            archive.CreateEntryFromFile(path, Path.GetFileName(path), CompressionLevel.Optimal);
        }

        private static void CopyIfExists(string source, string dest)
        {
            if (!File.Exists(source)) return;
            File.Copy(source, dest, overwrite: true);
        }
    }
}
