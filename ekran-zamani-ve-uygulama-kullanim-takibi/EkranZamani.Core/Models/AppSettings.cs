namespace EkranZamani.Models;

public class AppSettings
{
    public bool RunAtStartup { get; set; }
    public bool MinimizeToTrayOnClose { get; set; } = true;
    public bool LogWindowTitles { get; set; } = true;
    public bool EnableBrowserExtension { get; set; } = true;
    public bool EnableSyncApi { get; set; }
    public int SyncApiPort { get; set; } = 47124;
    public int BridgePort { get; set; } = 47123;
    public bool EnableGoalNotifications { get; set; } = true;
    public bool EnableWeeklyReport { get; set; } = true;
    public int WeeklyReportDayOfWeek { get; set; } = 0;
    public string? LastWeeklyReportDate { get; set; }
    public bool PomodoroBridgeEnabled { get; set; } = true;
    public bool EnableGlobalHotkey { get; set; } = true;
    public int DistractingLimitMinutes { get; set; } = 120;
    public bool EnableDistractingAlert { get; set; } = true;
    public string? LastDistractingAlertDate { get; set; }
    public int ProductiveStreakMinMinutes { get; set; } = 30;
    public int IdleThresholdMinutes { get; set; } = 5;
    /// <summary>Bu günden eski kullanım kayıtları otomatik silinir; 0 = süresiz sakla.</summary>
    public int RetentionDays { get; set; }
    public string Theme { get; set; } = "light";
    public List<string> AppBlacklist { get; set; } = new();

    public bool EnableWeeklyEmail { get; set; }
    public string? SmtpHost { get; set; }
    public int SmtpPort { get; set; } = 587;
    public bool SmtpUseSsl { get; set; } = true;
    public string? SmtpUser { get; set; }
    public string? SmtpPassword { get; set; }
    public string? EmailFrom { get; set; }
    public string? EmailTo { get; set; }
    public string? LastWeeklyEmailDate { get; set; }

    public bool EnableSyncExport { get; set; }
    public string? SyncExportFolder { get; set; }
    public int SyncExportIntervalMinutes { get; set; } = 60;
    public string? LastSyncExportUtc { get; set; }

    public bool EnableDailySummary { get; set; }
    public int DailySummaryHour { get; set; } = 21;
    public string? LastDailySummaryDate { get; set; }
}
