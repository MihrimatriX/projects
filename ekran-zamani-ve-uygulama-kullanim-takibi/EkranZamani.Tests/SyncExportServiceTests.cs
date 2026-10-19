using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class SyncExportServiceTests
{
    [Fact]
    public void ExportSnapshot_writes_json_file()
    {
        var dataFolder = Path.Combine(Path.GetTempPath(), "EkranZamani_syncdb_" + Guid.NewGuid().ToString("N"));
        var syncFolder = Path.Combine(Path.GetTempPath(), "EkranZamani_syncout_" + Guid.NewGuid().ToString("N"));
        var db = new DatabaseService(dataFolder);
        var categories = new CategoryService(db);
        var export = new ExportService(db, categories);
        var sync = new SyncExportService(db, categories, export);

        var settings = new AppSettings { EnableSyncExport = true, SyncExportFolder = syncFolder };
        var path = sync.ExportSnapshot(settings);

        Assert.NotNull(path);
        Assert.True(File.Exists(path));
        Assert.Contains("ekran-zamani-sync.json", path);

        try { Directory.Delete(dataFolder, true); Directory.Delete(syncFolder, true); } catch { }
    }
}
