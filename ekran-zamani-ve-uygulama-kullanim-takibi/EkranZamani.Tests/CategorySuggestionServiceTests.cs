using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class CategorySuggestionServiceTests
{
    [Fact]
    public void GetSuggestions_returns_unruled_apps_with_default_category()
    {
        var folder = Path.Combine(Path.GetTempPath(), "EkranZamani_suggest_" + Guid.NewGuid().ToString("N"));
        var db = new DatabaseService(folder);
        var categories = new CategoryService(db);

        var day = DateTime.Now.Date;
        db.SaveUsageRecord("obsidian", "t", day.AddHours(1), day.AddHours(2), 3600);

        var service = new CategorySuggestionService(db, categories);
        var list = service.GetSuggestions(7, 5);

        Assert.Contains(list, s => s.Pattern == "obsidian");
        Assert.Equal(UsageCategory.Productive, list.First(s => s.Pattern == "obsidian").SuggestedCategory);

        try { Directory.Delete(folder, true); } catch { }
    }
}
