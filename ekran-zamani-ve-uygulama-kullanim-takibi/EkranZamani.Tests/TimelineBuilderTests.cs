using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class TimelineBuilderTests
{
    [Fact]
    public void Build_merges_adjacent_same_app_sessions()
    {
        var records = new List<UsageRecord>
        {
            new()
            {
                ProcessName = "code",
                WindowTitle = "a",
                StartTime = "2026-06-02 10:00:00",
                EndTime = "2026-06-02 10:05:00",
                DurationSeconds = 300
            },
            new()
            {
                ProcessName = "code",
                WindowTitle = "b",
                StartTime = "2026-06-02 10:05:30",
                EndTime = "2026-06-02 10:10:00",
                DurationSeconds = 270
            }
        };

        var segments = TimelineBuilder.Build(records, CategoryDefaults.GetCategory);

        Assert.Single(segments);
        Assert.Equal(570, segments[0].DurationSeconds);
        Assert.Equal("VS Code", segments[0].ProcessName);
    }

    [Fact]
    public void Build_returns_empty_for_no_records()
    {
        var segments = TimelineBuilder.Build(Array.Empty<UsageRecord>(), CategoryDefaults.GetCategory);
        Assert.Empty(segments);
    }

    [Fact]
    public void Build_inserts_idle_gap_when_sessions_far_apart()
    {
        var records = new List<UsageRecord>
        {
            new()
            {
                ProcessName = "code",
                WindowTitle = "a",
                StartTime = "2026-06-02 10:00:00",
                EndTime = "2026-06-02 10:30:00",
                DurationSeconds = 1800
            },
            new()
            {
                ProcessName = "code",
                WindowTitle = "b",
                StartTime = "2026-06-02 11:00:00",
                EndTime = "2026-06-02 11:30:00",
                DurationSeconds = 1800
            }
        };

        var segments = TimelineBuilder.Build(records, CategoryDefaults.GetCategory);

        Assert.Equal(3, segments.Count);
        Assert.Equal("Boşta", segments[1].ProcessName);
        Assert.Equal(1800, segments[1].DurationSeconds);
    }
}
