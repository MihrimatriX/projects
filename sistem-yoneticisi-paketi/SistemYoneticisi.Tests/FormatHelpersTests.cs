using Microsoft.Data.Sqlite;
using SistemYoneticisi.Helpers;
using SistemYoneticisi.Services;
using Xunit;

namespace SistemYoneticisi.Tests;

public class FormatHelpersTests
{
    [Theory]
    [InlineData(512, "512 Kbps")]
    [InlineData(1024, "1.0 Mbps")]
    [InlineData(2048, "2.0 Mbps")]
    public void FormatSpeed_formats_correctly(double kbps, string expected)
    {
        Assert.Equal(expected, FormatHelpers.FormatSpeed(kbps));
    }

    [Fact]
    public void FormatDiskSummary_includes_both_values()
    {
        var summary = FormatHelpers.FormatDiskSummary(120.5, 500.0);
        Assert.Equal("120.5 GB kullanıldı / 500.0 GB", summary);
    }
}

public class ProcessProtectionTests
{
    [Theory]
    [InlineData(4, "System", "C:\\Windows\\System32\\ntoskrnl.exe", true)]
    [InlineData(1234, "notepad", "C:\\Windows\\notepad.exe", false)]
    public void ProcessInfo_canKill_reflects_protection(int pid, string name, string path, bool isProtected)
    {
        var info = new ProcessInfo
        {
            Pid = pid,
            Name = name,
            Path = path,
            IsProtected = pid <= 4 || path == "Erişim Engellendi"
        };

        Assert.Equal(isProtected, !info.CanKill);
    }
}

public class MetricsHistoryServiceTests : IDisposable
{
    private readonly string _dbPath;
    private readonly MetricsHistoryService _service;

    public MetricsHistoryServiceTests()
    {
        _dbPath = Path.Combine(Path.GetTempPath(), $"syp-test-{Guid.NewGuid():N}.db");
        Environment.SetEnvironmentVariable("SYP_TEST_DB", _dbPath);
        // Use direct connection path override via temp AppPaths is hard — test via public API with custom db
        _service = new MetricsHistoryService(_dbPath);
    }

    [Fact]
    public void RecordSample_and_GetRecentMinutes_roundtrip()
    {
        _service.RecordSample(42.5, 61.2);
        var samples = _service.GetRecentMinutes(5);
        Assert.NotEmpty(samples);
        Assert.Equal(42.5, samples[^1].Cpu, 1);
        Assert.Equal(61.2, samples[^1].Ram, 1);
    }

    [Fact]
    public void ExportCsv_writes_header_and_row()
    {
        _service.RecordSample(10, 20);
        var csv = Path.Combine(Path.GetTempPath(), $"syp-export-{Guid.NewGuid():N}.csv");
        _service.ExportCsv(csv, 1);
        var lines = File.ReadAllLines(csv);
        Assert.True(lines.Length >= 2);
        Assert.Contains("cpu_percent", lines[0]);
        File.Delete(csv);
    }

    public void Dispose()
    {
        _service.Dispose();
        SqliteConnection.ClearAllPools();
        try
        {
            if (File.Exists(_dbPath))
                File.Delete(_dbPath);
        }
        catch
        {
            // Temp file cleanup best-effort on Windows file locks.
        }
    }
}

[Collection("SettingsTests")]
public class AlarmServiceTests
{
    [Fact]
    public void Alarm_fires_after_duration_threshold()
    {
        var settings = new AppSettings
        {
            AlarmsEnabled = true,
            CpuAlarmThreshold = 90,
            AlarmDurationSeconds = 3
        };
        SettingsService.Instance.Settings = settings;

        var alarm = new AlarmService();
        string? title = null;
        alarm.AlarmTriggered += (t, _) => title = t;

        alarm.Evaluate(95, 10);
        alarm.Evaluate(95, 10);
        Assert.Null(title);
        alarm.Evaluate(95, 10);
        Assert.Equal("CPU alarmı", title);
    }
}
