using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class ActivityWatchServiceTests
{
    [Fact]
    public void ParseEvents_reads_array_and_nested_events()
    {
        const string json = """
        {
          "events": [
            {
              "timestamp": "2026-06-02T10:00:00",
              "duration": 120,
              "data": { "app": "firefox", "title": "Docs", "url": "https://example.com" }
            }
          ]
        }
        """;

        var events = ActivityWatchService.ParseEvents(json);
        Assert.Single(events);
        Assert.Equal("firefox", events[0].App);
        Assert.Equal(120, events[0].Duration);
    }
}
