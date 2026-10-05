using EkranZamani.Models;
using EkranZamani.Services;
using Microsoft.Data.Sqlite;
using Xunit;

namespace EkranZamani.Tests;

/// <summary>İzleme doğruluğu: uygulama geçişi, boşta, kilit, uyku, gece yarısı, gizli uygulama.</summary>
public class TrackingAccuracyTests : IDisposable
{
    private static readonly IntPtr ChromeHwnd = new(1), CodeHwnd = new(2), KeeHwnd = new(3);
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "EkranZamani_track_" + Guid.NewGuid().ToString("N"));
    private readonly DatabaseService _db;
    private readonly AppSettings _settings = new() { IdleThresholdMinutes = 1 };
    private readonly TrackingService _tracker;
    private readonly DateTime _t0 = new(2026, 3, 10, 10, 0, 0);

    public TrackingAccuracyTests()
    {
        _db = new DatabaseService(_dir);
        _tracker = new TrackingService(_db, () => _settings);
        _tracker.StartInternal(_t0);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        try { Directory.Delete(_dir, true); } catch { /* ignore */ }
    }

    private void Run(int fromSec, int toSec, IntPtr hwnd, string proc, Func<int, double>? idle = null, bool locked = false)
    {
        for (int i = fromSec; i <= toSec; i++)
            _tracker.Tick(_t0.AddSeconds(i), idle?.Invoke(i) ?? 0, locked, hwnd, proc, proc + " pencere");
    }

    private Dictionary<string, int> Totals()
    {
        using var conn = new SqliteConnection($"Data Source={Path.Combine(_dir, "usage.db")}");
        conn.Open();
        using var cmd = new SqliteCommand("SELECT ProcessName, SUM(DurationSeconds) FROM WindowUsage GROUP BY ProcessName;", conn);
        using var r = cmd.ExecuteReader();
        var d = new Dictionary<string, int>();
        while (r.Read()) d[r.GetString(0)] = r.GetInt32(1);
        return d;
    }

    private List<(string Start, string End, int Dur)> Rows(string table = "WindowUsage")
    {
        using var conn = new SqliteConnection($"Data Source={Path.Combine(_dir, "usage.db")}");
        conn.Open();
        using var cmd = new SqliteCommand($"SELECT StartTime, EndTime, DurationSeconds FROM {table} ORDER BY StartTime;", conn);
        using var r = cmd.ExecuteReader();
        var list = new List<(string, string, int)>();
        while (r.Read()) list.Add((r.GetString(0), r.GetString(1), r.GetInt32(2)));
        return list;
    }

    [Fact]
    public void App_switch_attributes_time_to_each_app()
    {
        Run(0, 45, ChromeHwnd, "chrome");
        Run(46, 100, CodeHwnd, "Code");
        _tracker.Stop(_t0.AddSeconds(100));

        var t = Totals();
        Assert.Equal(46, t["chrome"]);
        Assert.Equal(54, t["Code"]);
    }

    [Fact]
    public void Idle_time_before_threshold_is_removed_retroactively()
    {
        // 10. saniyeden sonra girdi yok; eşik 60 sn → 70. saniyede boşta. Aradaki 60 sn sayılmamalı.
        Run(0, 120, ChromeHwnd, "chrome", idle: i => Math.Max(0, i - 10));
        // Kullanıcı döner, 30 sn daha çalışır.
        Run(121, 150, ChromeHwnd, "chrome");
        _tracker.Stop(_t0.AddSeconds(150));

        Assert.Equal(10 + 29, Totals()["chrome"]);
    }

    [Fact]
    public void Lock_screen_stops_counting_immediately()
    {
        Run(0, 20, ChromeHwnd, "chrome");
        Run(21, 300, IntPtr.Zero, "LockApp", locked: true);
        Run(301, 310, ChromeHwnd, "chrome");
        _tracker.Stop(_t0.AddSeconds(310));

        var t = Totals();
        Assert.Equal(21 + 9, t["chrome"]);
        Assert.False(t.ContainsKey("LockApp"));
    }

    [Fact]
    public void Sleep_gap_is_not_counted()
    {
        Run(0, 10, ChromeHwnd, "chrome");
        // Bilgisayar 8 saat uyudu; uyanınca aynı pencere ön planda.
        Run(8 * 3600, 8 * 3600 + 5, ChromeHwnd, "chrome");
        _tracker.Stop(_t0.AddSeconds(8 * 3600 + 5));

        Assert.Equal(15, Totals()["chrome"]);
    }

    [Fact]
    public void Blacklisted_app_is_not_recorded_and_closes_previous_session()
    {
        Run(0, 10, ChromeHwnd, "chrome");
        Run(11, 60, KeeHwnd, "KeePassXC");
        Run(61, 70, ChromeHwnd, "chrome");
        _tracker.Stop(_t0.AddSeconds(70));

        var t = Totals();
        Assert.Equal(11 + 9, t["chrome"]);
        Assert.Single(t);
    }

    [Fact]
    public void Window_titles_are_not_stored_when_disabled()
    {
        _settings.LogWindowTitles = false;
        Run(0, 5, ChromeHwnd, "chrome");
        _tracker.Stop(_t0.AddSeconds(5));

        using var conn = new SqliteConnection($"Data Source={Path.Combine(_dir, "usage.db")}");
        conn.Open();
        using var cmd = new SqliteCommand("SELECT COUNT(*) FROM WindowUsage WHERE WindowTitle <> '';", conn);
        Assert.Equal(0L, (long)cmd.ExecuteScalar()!);
    }

    [Fact]
    public void Record_crossing_midnight_is_split_per_day()
    {
        var start = new DateTime(2026, 3, 10, 23, 59, 50);
        _db.SaveUsageRecord("Code", "", start, start.AddSeconds(30), 30);
        _db.SaveWebDomainUsage("github.com", "", start, start.AddSeconds(30), 30);

        foreach (var table in new[] { "WindowUsage", "WebDomainUsage" })
        {
            var rows = Rows(table);
            Assert.Equal(2, rows.Count);
            Assert.Equal(("2026-03-10 23:59:50", "2026-03-11 00:00:00", 10), rows[0]);
            Assert.Equal(("2026-03-11 00:00:00", "2026-03-11 00:00:20", 20), rows[1]);
        }
    }

    [Fact]
    public void SplitAtMidnight_keeps_total_over_multiple_days()
    {
        var start = new DateTime(2026, 3, 10, 22, 0, 0);
        var parts = DatabaseService.SplitAtMidnight(start, start.AddHours(28), 28 * 3600);
        Assert.Equal(3, parts.Count);
        Assert.Equal(28 * 3600, parts.Sum(p => p.Duration));
        Assert.Equal(2 * 3600, parts[0].Duration);
        // Tam gece yarısında biten kayıt bölünmez.
        Assert.Single(DatabaseService.SplitAtMidnight(start, start.AddHours(2), 7200));
    }

    [Fact]
    public void PurgeOlderThan_deletes_only_old_rows()
    {
        var old = DateTime.Now.Date.AddDays(-40).AddHours(10);
        var recent = DateTime.Now.Date.AddDays(-2).AddHours(10);
        _db.SaveUsageRecord("old", "", old, old.AddMinutes(1), 60);
        _db.SaveUsageRecord("recent", "", recent, recent.AddMinutes(1), 60);
        _db.SaveWebDomainUsage("old.com", "", old, old.AddMinutes(1), 60);

        Assert.Equal(0, _db.PurgeOlderThan(0)); // 0 = süresiz
        Assert.Equal(2, _db.PurgeOlderThan(30));
        Assert.Equal(new[] { "recent" }, Totals().Keys.ToArray());
        Assert.Empty(Rows("WebDomainUsage"));
    }
}
