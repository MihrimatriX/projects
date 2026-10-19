using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class ProductiveStreakServiceTests
{
    [Fact]
    public void ComputeStreak_counts_consecutive_productive_days()
    {
        var folder = Path.Combine(Path.GetTempPath(), "EkranZamani_test_" + Guid.NewGuid().ToString("N"));
        var db = new DatabaseService(folder);
        var categories = new CategoryService(db);
        db.AddCategoryRule("workapp", UsageCategory.Productive, 100);

        // Sabit gün: SQLite datetime('now','localtime') ile uyumlu, gece yarısı flakiness yok
        var anchor = DateTime.Today;
        for (int daysAgo = 0; daysAgo < 3; daysAgo++)
        {
            var day = anchor.AddDays(-daysAgo);
            db.SaveUsageRecord("workapp", "t", day.AddHours(10), day.AddHours(11), 3600);
        }

        var streak = new ProductiveStreakService(db, categories).ComputeStreak(30);
        Assert.Equal(3, streak);

        try { Directory.Delete(folder, true); } catch { }
    }
}
