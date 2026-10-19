using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Microsoft.Win32;

namespace SistemYoneticisi.Services
{
    public class StartupService
    {
        public const string DefaultRunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";

        private readonly string _runKeyPath;
        private readonly string? _userStartupDir;
        private readonly string? _commonStartupDir;
        private readonly string _backupDir;

        public StartupService()
            : this(DefaultRunKeyPath,
                Environment.GetFolderPath(Environment.SpecialFolder.Startup),
                Environment.GetFolderPath(Environment.SpecialFolder.CommonStartup),
                AppPaths.StartupBackupDir)
        {
        }

        /// <summary>Testler gerçek başlangıç öğelerine dokunmamak için kayıt anahtarı ve klasörleri değiştirir.</summary>
        internal StartupService(string runKeyPath, string? userStartupDir, string? commonStartupDir, string backupDir)
        {
            _runKeyPath = runKeyPath;
            _userStartupDir = userStartupDir;
            _commonStartupDir = commonStartupDir;
            _backupDir = backupDir;
        }

        private string BackupIndexFile => Path.Combine(_backupDir, "removed.json");

        public List<StartupItem> GetStartupItems()
        {
            var items = new List<StartupItem>();

            ReadRegistryRunKey(Registry.CurrentUser, "Kullanıcı (HKCU)", items);
            ReadRegistryRunKey(Registry.LocalMachine, "Sistem (HKLM)", items);

            ReadStartupFolder(_userStartupDir, true, "Kullanıcı Başlangıç Klasörü", items);
            ReadStartupFolder(_commonStartupDir, false, "Ortak Başlangıç Klasörü", items);

            return items;
        }

        private void ReadRegistryRunKey(RegistryKey hive, string location, List<StartupItem> list)
        {
            try
            {
                using var key = hive.OpenSubKey(_runKeyPath, false);
                if (key == null) return;

                foreach (var valueName in key.GetValueNames())
                {
                    var value = key.GetValue(valueName);
                    if (value == null) continue;

                    list.Add(new StartupItem
                    {
                        Name = valueName,
                        Command = value.ToString() ?? string.Empty,
                        Location = location,
                        IsCurrentUser = hive == Registry.CurrentUser,
                        ItemType = StartupItemType.Registry
                    });
                }
            }
            catch (Exception ex)
            {
                LogService.Error($"Registry startup read failed ({location})", ex);
            }
        }

        private static void ReadStartupFolder(string? path, bool isCurrentUser, string location, List<StartupItem> list)
        {
            try
            {
                if (string.IsNullOrEmpty(path) || !Directory.Exists(path)) return;

                foreach (var file in Directory.GetFiles(path))
                {
                    // desktop.ini gizli sistem dosyasıdır, başlangıç öğesi değildir.
                    if (string.Equals(Path.GetFileName(file), "desktop.ini", StringComparison.OrdinalIgnoreCase)) continue;

                    list.Add(new StartupItem
                    {
                        Name = Path.GetFileNameWithoutExtension(file),
                        Command = file,
                        Location = location,
                        FilePath = file,
                        ItemType = StartupItemType.Folder,
                        IsCurrentUser = isCurrentUser
                    });
                }
            }
            catch (Exception ex)
            {
                LogService.Error($"Startup folder read failed ({location})", ex);
            }
        }

        /// <summary>
        /// Öğeyi başlangıçtan kaldırır; geri alınabilmesi için önce yedekler
        /// (kısayol dosyası silinmez, yedek klasörüne taşınır).
        /// </summary>
        public bool RemoveStartupItem(StartupItem item)
        {
            var backups = LoadBackups();
            try
            {
                if (item.ItemType == StartupItemType.Folder)
                {
                    if (!File.Exists(item.FilePath)) return false;

                    var filesDir = Path.Combine(_backupDir, "files");
                    Directory.CreateDirectory(filesDir);
                    var backupFile = Path.Combine(filesDir, $"{Guid.NewGuid():N}_{Path.GetFileName(item.FilePath)}");
                    File.Move(item.FilePath, backupFile);

                    backups.Add(new RemovedStartupItem
                    {
                        Name = item.Name, ItemType = item.ItemType, IsCurrentUser = item.IsCurrentUser,
                        FilePath = item.FilePath, BackupFile = backupFile, RemovedAt = DateTime.Now
                    });
                    SaveBackups(backups);
                    return true;
                }

                var hive = item.IsCurrentUser ? Registry.CurrentUser : Registry.LocalMachine;
                using var key = hive.OpenSubKey(_runKeyPath, true);
                var raw = key?.GetValue(item.Name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                if (key == null || raw == null) return false;

                // Önce yedeği kaydet, sonra sil: silme sonrası yedek yazılamazsa komut kaybolurdu.
                backups.Add(new RemovedStartupItem
                {
                    Name = item.Name, ItemType = item.ItemType, IsCurrentUser = item.IsCurrentUser,
                    Command = raw.ToString() ?? string.Empty,
                    ValueKind = key.GetValueKind(item.Name).ToString(),
                    RemovedAt = DateTime.Now
                });
                SaveBackups(backups);
                try
                {
                    key.DeleteValue(item.Name, false);
                }
                catch
                {
                    backups.RemoveAt(backups.Count - 1);
                    SaveBackups(backups);
                    throw;
                }
                return true;
            }
            catch (Exception ex)
            {
                LogService.Error("Startup item removal failed", ex);
            }

            return false;
        }

        public bool HasRemovedItems => LoadBackups().Count > 0;

        /// <summary>En son kaldırılan öğeyi geri yükler. Başarılıysa öğenin adını döndürür.</summary>
        public string? RestoreLastRemoved()
        {
            var backups = LoadBackups();
            if (backups.Count == 0) return null;
            var last = backups[^1];

            try
            {
                if (last.ItemType == StartupItemType.Folder)
                {
                    if (!File.Exists(last.BackupFile) || File.Exists(last.FilePath)) return null;
                    Directory.CreateDirectory(Path.GetDirectoryName(last.FilePath)!);
                    File.Move(last.BackupFile, last.FilePath);
                }
                else
                {
                    var hive = last.IsCurrentUser ? Registry.CurrentUser : Registry.LocalMachine;
                    using var key = hive.CreateSubKey(_runKeyPath, true);
                    if (key.GetValue(last.Name) != null) return null; // aynı adla yeni bir öğe var; üzerine yazma
                    var kind = Enum.TryParse<RegistryValueKind>(last.ValueKind, out var k) && k == RegistryValueKind.ExpandString
                        ? RegistryValueKind.ExpandString
                        : RegistryValueKind.String;
                    key.SetValue(last.Name, last.Command, kind);
                }

                backups.RemoveAt(backups.Count - 1);
                SaveBackups(backups);
                return last.Name;
            }
            catch (Exception ex)
            {
                LogService.Error("Startup item restore failed", ex);
                return null;
            }
        }

        private List<RemovedStartupItem> LoadBackups()
        {
            try
            {
                if (!File.Exists(BackupIndexFile)) return new();
                return JsonSerializer.Deserialize<List<RemovedStartupItem>>(File.ReadAllText(BackupIndexFile)) ?? new();
            }
            catch (Exception ex)
            {
                LogService.Error("Startup backup read failed", ex);
                return new();
            }
        }

        private void SaveBackups(List<RemovedStartupItem> backups)
        {
            Directory.CreateDirectory(_backupDir);
            var tmp = BackupIndexFile + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(backups, new JsonSerializerOptions { WriteIndented = true }));
            File.Move(tmp, BackupIndexFile, true);
        }
    }

    public enum StartupItemType
    {
        Registry,
        Folder
    }

    public class StartupItem
    {
        public string Name { get; set; } = string.Empty;
        public string Command { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public bool IsCurrentUser { get; set; }
        public StartupItemType ItemType { get; set; }
    }

    public class RemovedStartupItem
    {
        public string Name { get; set; } = string.Empty;
        public StartupItemType ItemType { get; set; }
        public bool IsCurrentUser { get; set; }
        public string Command { get; set; } = string.Empty;
        public string ValueKind { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public string BackupFile { get; set; } = string.Empty;
        public DateTime RemovedAt { get; set; }
    }
}
