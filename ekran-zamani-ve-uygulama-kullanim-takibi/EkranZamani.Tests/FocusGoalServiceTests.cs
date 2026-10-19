using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class FocusGoalServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly DatabaseService _db;

    public FocusGoalServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "EkranZamaniGoalTests", Guid.NewGuid().ToString("N"));
        _db = new DatabaseService(_tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, true); } catch { }
    }

    [Fact]
    public void GetTodayProgress_calculates_matching_process_seconds()
    {
        _db.SaveUsageRecord("Code", "file.cs", DateTime.Today.AddHours(9), DateTime.Today.AddHours(10), 3600);
        var goals = _db.GetFocusGoals();
        var coding = goals.First(g => g.MatchPattern == "code");
        int seconds = _db.GetTodaySecondsForGoal(coding, CategoryDefaults.GetCategory);
        Assert.True(seconds >= 3600);
    }
}
