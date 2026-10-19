using System.IO;

namespace UygulamaBaslatici.Services;

public sealed class AppScannerService
{
    private readonly DatabaseService _db;
    private volatile bool _isScanning;

    public event Action<string>? StatusChanged;
    public event Action<int>? FoundCountChanged;
    public event Action? ScanningCompleted;

    public AppScannerService(DatabaseService db) => _db = db;

    public bool IsScanning => _isScanning;

    public void ScanStartMenu()
    {
        if (_isScanning) return;
        _isScanning = true;

        Task.Run(() =>
        {
            try
            {
                var roots = ScanRoots();

                var apps = new List<AppScannerData>();
                foreach (var root in roots.Where(Directory.Exists))
                {
                    StatusChanged?.Invoke(Path.GetFileName(root) ?? root);
                    ScanDirectory(root, apps, count => FoundCountChanged?.Invoke(count));
                }

                _db.BulkInsertApps(apps);
                StatusChanged?.Invoke("Hazır");
            }
            catch (Exception ex)
            {
                StatusChanged?.Invoke($"Hata: {ex.Message}");
            }
            finally
            {
                _isScanning = false;
                ScanningCompleted?.Invoke();
            }
        });
    }

    // Testler/demo gercek Baslat Menusu yerine sahte kisayol klasoru tarar.
    public const string ScanDirEnvVar = "KOMUT_PALETI_SCAN_DIR";

    internal static string[] ScanRoots() => Environment.GetEnvironmentVariable(ScanDirEnvVar) is { Length: > 0 } dir
        ? [dir]
        :
        [
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), @"Microsoft\Windows\Start Menu\Programs"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"Microsoft\Windows\Start Menu\Programs")
        ];

    private static void ScanDirectory(string dir, List<AppScannerData> apps, Action<int> onCount)
    {
        var stack = new Stack<string>();
        stack.Push(dir);

        while (stack.Count > 0)
        {
            var current = stack.Pop();

            string[] files;
            try { files = Directory.GetFiles(current); }
            catch { continue; }

            foreach (var file in files)
            {
                var ext = Path.GetExtension(file).ToLowerInvariant();
                if (ext is not (".lnk" or ".url")) continue;

                var name = Path.GetFileNameWithoutExtension(file);
                if (string.IsNullOrWhiteSpace(name)) continue;
                if (name.Contains("uninstall", StringComparison.OrdinalIgnoreCase) ||
                    name.Contains("kaldır", StringComparison.OrdinalIgnoreCase)) continue;

                apps.Add(new AppScannerData { Name = name, Path = file, Type = "App" });
                onCount(apps.Count);
            }

            try
            {
                foreach (var sub in Directory.GetDirectories(current))
                    stack.Push(sub);
            }
            catch { /* ponytail: skip unreadable dirs */ }
        }
    }
}
