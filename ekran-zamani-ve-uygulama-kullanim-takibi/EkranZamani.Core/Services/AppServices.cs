using System;
using System.Timers;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public static class AppServices
    {
        public static DatabaseService Database { get; private set; } = null!;
        public static CategoryService Categories { get; private set; } = null!;
        public static SettingsService Settings { get; private set; } = null!;
        public static ExportService Export { get; private set; } = null!;
        public static ActivityWatchService ActivityWatch { get; private set; } = null!;
        public static FocusGoalService FocusGoals { get; private set; } = null!;
        public static PomodoroBridgeService PomodoroBridge { get; private set; } = null!;
        public static WeeklyReportService WeeklyReport { get; private set; } = null!;
        public static WeeklyEmailService WeeklyEmail { get; private set; } = null!;
        public static SyncExportService SyncExport { get; private set; } = null!;
        public static SyncImportService SyncImport { get; private set; } = null!;
        public static SyncApiHostService SyncApi { get; private set; } = null!;
        public static DailySummaryService DailySummary { get; private set; } = null!;
        public static CategorySuggestionService CategorySuggestions { get; private set; } = null!;
        public static BridgeHostService BridgeHost { get; private set; } = null!;
        public static BackupService Backup { get; private set; } = null!;
        public static ProductiveStreakService Streak { get; private set; } = null!;
        public static UsageAlertService UsageAlerts { get; private set; } = null!;

        /// <summary>UI katmanı tema uygulaması (WPF / WinUI).</summary>
        public static Action<string>? ApplyTheme { get; set; }

        public static event Action<string>? DailySummaryReady;

        private static System.Timers.Timer? _goalTimer;

        public static void Initialize()
        {
            Database = new DatabaseService();
            Categories = new CategoryService(Database);
            Settings = new SettingsService(Database.DataFolder);
            Export = new ExportService(Database, Categories);
            ActivityWatch = new ActivityWatchService(Database, Categories);
            FocusGoals = new FocusGoalService(Database, Categories);
            PomodoroBridge = new PomodoroBridgeService(Database.DataFolder);
            WeeklyReport = new WeeklyReportService(Database, Categories);
            WeeklyEmail = new WeeklyEmailService(Database, Categories);
            SyncExport = new SyncExportService(Database, Categories, Export);
            SyncImport = new SyncImportService(Database);
            SyncApi = new SyncApiHostService(SyncExport, SyncImport, () => Settings.Current);
            DailySummary = new DailySummaryService(Database, Categories);
            CategorySuggestions = new CategorySuggestionService(Database, Categories);
            BridgeHost = new BridgeHostService(Database);
            Backup = new BackupService(Database, Settings);
            Streak = new ProductiveStreakService(Database, Categories);
            UsageAlerts = new UsageAlertService(Database, Categories);

            var settings = Settings.Current;
            ApplyTheme?.Invoke(settings.Theme);

            Settings.ApplyStartupSetting();
            Database.PurgeOlderThan(settings.RetentionDays);
            BridgeHost.Start(settings.BridgePort);
            RestartSyncApi();
            WeeklyReport.TryAutoGenerate(settings);
            TryWeeklyEmail(settings);
            SyncExport.TryExportIfDue(settings);
            Settings.Save(settings);

            _goalTimer = new System.Timers.Timer(60_000);
            _goalTimer.Elapsed += (_, _) => OnTimerTick();
            _goalTimer.Start();
        }

        private static void OnTimerTick()
        {
            var s = Settings.Current;
            FocusGoals.CheckAndNotify(s.EnableGoalNotifications);
            UsageAlerts.CheckDistractingLimit(s);

            var summary = DailySummary.TryBuildTodaySummary(s);
            if (summary != null)
                DailySummaryReady?.Invoke(summary);

            SyncExport.TryExportIfDue(s);
            TryWeeklyEmail(s);
            Database.PurgeOlderThan(s.RetentionDays); // StartTime indeksli; dakikada bir çalışması ucuz

            Settings.Save(s);
        }

        private static void TryWeeklyEmail(AppSettings settings)
        {
            if (!WeeklyEmail.IsConfigured(settings)) return;

            var today = DateTime.Now;
            if ((int)today.DayOfWeek != settings.WeeklyReportDayOfWeek) return;
            if (settings.LastWeeklyEmailDate == today.ToString("yyyy-MM-dd")) return;

            try
            {
                WeeklyEmail.TrySendWeekly(settings, WeeklyReport.GenerateHtmlReport());
                settings.LastWeeklyEmailDate = today.ToString("yyyy-MM-dd");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Weekly email failed: {ex.Message}");
            }
        }

        public static void RestartBridge() => BridgeHost.Start(Settings.Current.BridgePort);

        public static void RestartSyncApi()
        {
            var s = Settings.Current;
            if (s.EnableSyncApi)
                SyncApi.Start(s.SyncApiPort);
            else
                SyncApi.Stop();
        }

        public static void Shutdown()
        {
            _goalTimer?.Stop();
            _goalTimer?.Dispose();
            SyncApi.Dispose();
            BridgeHost.Dispose();
            SingleInstanceService.Dispose();
        }
    }
}
