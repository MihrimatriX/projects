using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace HizliDosyaArama.Services;

public class IndexerService
{
    private static readonly string[] SkipDirs = [".git", "node_modules", "bin", "obj", "AppData"];

    // Junction/symlink klasörleri atlanır; aksi halde döngüye girip aynı ağacı tekrar tekrar tarayabilir
    private static readonly EnumerationOptions SubDirOptions = new() { AttributesToSkip = FileAttributes.ReparsePoint };

    private readonly DatabaseService _db;
    private volatile bool _isIndexing;

    public event Action<string>? StatusChanged;
    public event Action? IndexingCompleted;

    private readonly IEnumerable<string>? _folders;

    // folders: testler için; null ise kullanıcı klasörleri (Belgeler, Masaüstü, İndirilenler, projeler) taranır.
    public IndexerService(DatabaseService db, IEnumerable<string>? folders = null)
    {
        _db = db;
        _folders = folders;
    }

    public bool IsIndexing => _isIndexing;

    public void StartIndexing()
    {
        if (_isIndexing) return;
        _isIndexing = true;

        Task.Run(async () =>
        {
            try
            {
                StatusChanged?.Invoke("Hazırlanıyor...");
                _db.ClearDatabase();

                var batch = new List<IndexedFileData>(1000);
                foreach (var folder in _folders ?? GetTargetFolders())
                {
                    if (!_isIndexing) break;
                    if (!Directory.Exists(folder)) continue;

                    StatusChanged?.Invoke($"{Path.GetFileName(folder)} taranıyor...");
                    await ScanAsync(folder, batch);
                }

                if (batch.Count > 0)
                    _db.BulkInsertFiles(batch);

                var total = _db.GetIndexedCount();
                StatusChanged?.Invoke($"Hazır ({total:N0} dosya)");
            }
            catch (Exception ex)
            {
                StatusChanged?.Invoke($"Hata: {ex.Message}");
            }
            finally
            {
                _isIndexing = false;
                IndexingCompleted?.Invoke();
            }
        });
    }

    private static IEnumerable<string> GetTargetFolders()
    {
        var profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        yield return Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        yield return Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
        yield return Path.Combine(profile, "Downloads");

        foreach (var candidate in new[]
        {
            Path.Combine(profile, "Desktop", "DEV", "projects"),
            Path.Combine(profile, "Desktop", "projects"),
            Path.Combine(profile, "DEV", "projects")
        })
        {
            if (Directory.Exists(candidate))
                yield return candidate;
        }
    }

    // Özyineleme yerine yığınla (stack) tarama; her 1000 dosyada bir tek transaction'lık toplu INSERT yapılır
    private async Task ScanAsync(string root, List<IndexedFileData> batch)
    {
        var stack = new Stack<string>();
        stack.Push(root);

        while (stack.Count > 0)
        {
            if (!_isIndexing) return;

            var dir = stack.Pop();
            var dirName = Path.GetFileName(dir);
            if (dirName.StartsWith('.') || Array.Exists(SkipDirs, s => s.Equals(dirName, StringComparison.OrdinalIgnoreCase)))
                continue;

            try
            {
                foreach (var file in Directory.EnumerateFiles(dir))
                {
                    try
                    {
                        var info = new FileInfo(file);
                        batch.Add(new IndexedFileData
                        {
                            FileName = info.Name,
                            FilePath = info.FullName,
                            Extension = info.Extension,
                            Size = info.Length,
                            LastWriteTime = info.LastWriteTime
                        });

                        if (batch.Count >= 1000)
                        {
                            _db.BulkInsertFiles(batch);
                            batch.Clear();
                            await Task.Yield();
                        }
                    }
                    catch { /* locked file */ }
                }

                foreach (var sub in Directory.EnumerateDirectories(dir, "*", SubDirOptions))
                    stack.Push(sub);
            }
            catch (UnauthorizedAccessException) { }
            catch (IOException) { } // DirectoryNotFound, PathTooLong, ağ hatası: o klasörü atla, tüm taramayı düşürme
        }
    }
}
