using System.Text.Json;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class SyncImportServiceTests
{
    [Fact]
    public void ImportFromFile_merges_remote_apps()
    {
        var folder = Path.Combine(Path.GetTempPath(), "EkranZamani_import_" + Guid.NewGuid().ToString("N"));
        var db = new DatabaseService(folder);
        var import = new SyncImportService(db);

        var jsonPath = Path.Combine(folder, "sync.json");
        var payload = new
        {
            device = "laptop-b",
            apps = new[] { new { processName = "obsidian", totalSeconds = 1200 } }
        };
        File.WriteAllText(jsonPath, JsonSerializer.Serialize(payload));

        int count = import.ImportFromFile(jsonPath);

        Assert.Equal(1, count);
        Assert.Contains(db.GetAppUsageSummary(7), a => a.ProcessName.Contains("laptop-b"));

        try { Directory.Delete(folder, true); } catch { }
    }
}
