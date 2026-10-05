using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class CategoryServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly DatabaseService _db;

    public CategoryServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "EkranZamaniTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
        _db = new DatabaseService(_tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, true); } catch { /* ignore */ }
    }

    [Fact]
    public void GetCategory_prefers_custom_rule_over_default()
    {
        _db.AddCategoryRule("notepad", UsageCategory.Distracting, priority: 200);
        var service = new CategoryService(_db);

        Assert.Equal(UsageCategory.Distracting, service.GetCategory("notepad"));
    }
}
