using System;
using System.Collections.Generic;
using System.IO;
using EkranZamani.Models;
using Microsoft.Data.Sqlite;

namespace EkranZamani.Services
{
    public class DatabaseService
    {
        private readonly string _dbPath;
        private readonly string _connectionString;

        public string DataFolder { get; }

        public DatabaseService(string? dataFolderOverride = null)
        {
            // EKRANZAMANI_DATA_DIR: testler / taşınabilir kullanım için veri klasörünü değiştirir.
            var envDir = Environment.GetEnvironmentVariable("EKRANZAMANI_DATA_DIR");
            DataFolder = dataFolderOverride ?? (!string.IsNullOrWhiteSpace(envDir) ? envDir : Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "EkranZamani"));
            Directory.CreateDirectory(DataFolder);

            _dbPath = Path.Combine(DataFolder, "usage.db");
            _connectionString = $"Data Source={_dbPath}";
            InitializeDatabase();
        }

        private void InitializeDatabase()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS WindowUsage (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ProcessName TEXT NOT NULL,
                    WindowTitle TEXT NOT NULL,
                    StartTime DATETIME NOT NULL,
                    EndTime DATETIME NOT NULL,
                    DurationSeconds INTEGER NOT NULL
                );");

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS CategoryRules (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Pattern TEXT NOT NULL,
                    Category INTEGER NOT NULL,
                    Priority INTEGER NOT NULL DEFAULT 0
                );");

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS FocusGoals (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Title TEXT NOT NULL,
                    MatchPattern TEXT NOT NULL,
                    TargetMinutes INTEGER NOT NULL,
                    RequiredCategory INTEGER,
                    NotifyOnComplete INTEGER NOT NULL DEFAULT 1,
                    IsEnabled INTEGER NOT NULL DEFAULT 1
                );");

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS WebDomainUsage (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Domain TEXT NOT NULL,
                    PageTitle TEXT NOT NULL,
                    StartTime DATETIME NOT NULL,
                    EndTime DATETIME NOT NULL,
                    DurationSeconds INTEGER NOT NULL
                );");

            Execute(conn, @"
                CREATE TABLE IF NOT EXISTS GoalNotifications (
                    GoalId INTEGER NOT NULL,
                    NotifiedDate TEXT NOT NULL,
                    PRIMARY KEY (GoalId, NotifiedDate)
                );");

            Execute(conn, "CREATE INDEX IF NOT EXISTS idx_windowusage_start ON WindowUsage(StartTime);");
            Execute(conn, "CREATE INDEX IF NOT EXISTS idx_windowusage_process ON WindowUsage(ProcessName);");
            Execute(conn, "CREATE INDEX IF NOT EXISTS idx_webdomain_start ON WebDomainUsage(StartTime);");

            SeedDefaultCategoryRulesIfEmpty(conn);
            SeedDefaultFocusGoalsIfEmpty(conn);
        }

        private static void Execute(SqliteConnection conn, string sql)
        {
            using var cmd = new SqliteCommand(sql, conn);
            cmd.ExecuteNonQuery();
        }

        private void SeedDefaultCategoryRulesIfEmpty(SqliteConnection conn)
        {
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM CategoryRules;", conn);
            var count = Convert.ToInt32(countCmd.ExecuteScalar());
            if (count > 0) return;

            var defaults = new (string Pattern, UsageCategory Category, int Priority)[]
            {
                ("steam", UsageCategory.Distracting, 100),
                ("discord", UsageCategory.Distracting, 90),
                ("spotify", UsageCategory.Distracting, 90),
                ("netflix", UsageCategory.Distracting, 90),
                ("devenv", UsageCategory.Productive, 100),
                ("Code", UsageCategory.Productive, 95),
                ("rider", UsageCategory.Productive, 95),
                ("powershell", UsageCategory.Productive, 80),
                ("chrome", UsageCategory.Neutral, 50),
                ("msedge", UsageCategory.Neutral, 50),
                ("firefox", UsageCategory.Neutral, 50),
            };

            foreach (var (pattern, category, priority) in defaults)
            {
                InsertCategoryRule(conn, pattern, category, priority);
            }
        }

        public void SaveUsageRecord(string processName, string windowTitle, DateTime startTime, DateTime endTime, int duration)
        {
            if (duration <= 0) return;

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            // Gün raporları date(StartTime) ile gruplanır; gece yarısını aşan kayıt bölünmezse tüm süre önceki güne yazılır.
            foreach (var (s, e, d) in SplitAtMidnight(startTime, endTime, duration))
            {
                using var cmd = new SqliteCommand(@"
                    INSERT INTO WindowUsage (ProcessName, WindowTitle, StartTime, EndTime, DurationSeconds)
                    VALUES (@ProcessName, @WindowTitle, @StartTime, @EndTime, @DurationSeconds);", conn);
                cmd.Parameters.AddWithValue("@ProcessName", processName);
                cmd.Parameters.AddWithValue("@WindowTitle", windowTitle);
                cmd.Parameters.AddWithValue("@StartTime", Fmt(s));
                cmd.Parameters.AddWithValue("@EndTime", Fmt(e));
                cmd.Parameters.AddWithValue("@DurationSeconds", d);
                cmd.ExecuteNonQuery();
            }
        }

        private static string Fmt(DateTime t) => t.ToString("yyyy-MM-dd HH:mm:ss");

        /// <summary>[start, end) aralığını gün sınırlarında böler; süre parçalara orantılı dağıtılır (toplam korunur).</summary>
        public static List<(DateTime Start, DateTime End, int Duration)> SplitAtMidnight(DateTime start, DateTime end, int duration)
        {
            var parts = new List<(DateTime, DateTime, int)>();
            if (end <= start || start.Date.AddDays(1) >= end)
            {
                parts.Add((start, end, duration));
                return parts;
            }

            double total = (end - start).TotalSeconds;
            int assigned = 0;
            for (var cursor = start; cursor < end;)
            {
                var next = cursor.Date.AddDays(1) < end ? cursor.Date.AddDays(1) : end;
                int d = next == end
                    ? duration - assigned
                    : (int)Math.Round(duration * (next - cursor).TotalSeconds / total);
                if (d > 0) parts.Add((cursor, next, d));
                assigned += d;
                cursor = next;
            }
            return parts;
        }

        /// <summary>
        /// Boşta kalma eşiği dolana kadar periyodik olarak yazılmış süreyi geri alır:
        /// cutoff'tan sonra başlayan kayıtları siler, cutoff'u aşanları cutoff'ta keser.
        /// </summary>
        public void TrimWindowUsageAfter(DateTime cutoff)
        {
            string c = Fmt(cutoff);
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var del = new SqliteCommand("DELETE FROM WindowUsage WHERE StartTime >= @C;", conn);
            del.Parameters.AddWithValue("@C", c);
            del.ExecuteNonQuery();
            using var upd = new SqliteCommand(@"
                UPDATE WindowUsage
                SET EndTime = @C,
                    DurationSeconds = MIN(DurationSeconds, CAST(strftime('%s', @C) - strftime('%s', StartTime) AS INTEGER))
                WHERE EndTime > @C;", conn);
            upd.Parameters.AddWithValue("@C", c);
            upd.ExecuteNonQuery();
        }

        /// <summary>keepDays günden eski uygulama ve site kayıtlarını siler (0 = süresiz sakla). Silinen satır sayısını döner.</summary>
        public int PurgeOlderThan(int keepDays)
        {
            if (keepDays <= 0) return 0;
            string cutoff = Fmt(DateTime.Now.Date.AddDays(-keepDays));
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            int n = 0;
            foreach (var table in new[] { "WindowUsage", "WebDomainUsage" })
            {
                using var cmd = new SqliteCommand($"DELETE FROM {table} WHERE StartTime < @C;", conn);
                cmd.Parameters.AddWithValue("@C", cutoff);
                n += cmd.ExecuteNonQuery();
            }
            return n;
        }

        public List<AppUsageData> GetAppUsageSummary(int filterDays)
        {
            var list = new List<AppUsageData>();
            string dateFilterClause = GetDateFilterClause(filterDays);

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT ProcessName, SUM(DurationSeconds) as TotalSec
                FROM WindowUsage 
                {dateFilterClause}
                GROUP BY ProcessName
                ORDER BY TotalSec DESC;", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new AppUsageData
                {
                    ProcessName = reader.GetString(0),
                    TotalSeconds = reader.GetInt32(1)
                });
            }
            return list;
        }

        public List<UsageRecord> GetUsageRecords(int filterDays, bool ascending = false)
        {
            var list = new List<UsageRecord>();
            string dateFilterClause = GetDateFilterClause(filterDays);
            string order = ascending ? "ASC" : "DESC";

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT ProcessName, WindowTitle, StartTime, EndTime, DurationSeconds
                FROM WindowUsage
                {dateFilterClause}
                ORDER BY StartTime {order};", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new UsageRecord
                {
                    ProcessName = reader.GetString(0),
                    WindowTitle = reader.GetString(1),
                    StartTime = reader.GetString(2),
                    EndTime = reader.GetString(3),
                    DurationSeconds = reader.GetInt32(4)
                });
            }
            return list;
        }

        public List<DailyUsageData> GetDailyUsageSummary(int days = 7)
        {
            var list = new List<DailyUsageData>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(@"
                SELECT date(StartTime) as Day, SUM(DurationSeconds) as TotalSec
                FROM WindowUsage
                WHERE StartTime >= datetime('now', 'localtime', '-' || @Days || ' days', 'start of day')
                GROUP BY Day
                ORDER BY Day ASC;", conn);

            cmd.Parameters.AddWithValue("@Days", days);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new DailyUsageData
                {
                    Day = reader.GetString(0),
                    TotalSeconds = reader.GetInt32(1)
                });
            }
            return list;
        }

        public void DeleteAllData()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            Execute(conn, "DELETE FROM WindowUsage;");
            Execute(conn, "DELETE FROM WebDomainUsage;");
        }

        public int GetCategorySecondsForDay(int daysAgo, UsageCategory category, Func<string, UsageCategory> categorize)
        {
            var summary = GetAppUsageSummaryForDaysAgo(daysAgo);
            int total = 0;
            foreach (var item in summary)
            {
                if (categorize(item.ProcessName) == category)
                    total += item.TotalSeconds;
            }
            return total;
        }

        public List<AppUsageData> GetAppUsageSummaryForDaysAgo(int daysAgo)
        {
            var list = new List<AppUsageData>();
            string dateFilter = GetDateFilterForDaysAgo(daysAgo);

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT ProcessName, SUM(DurationSeconds) as TotalSec
                FROM WindowUsage
                {dateFilter}
                GROUP BY ProcessName
                ORDER BY TotalSec DESC;", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new AppUsageData
                {
                    ProcessName = reader.GetString(0),
                    TotalSeconds = reader.GetInt32(1)
                });
            }
            return list;
        }

        private static string GetDateFilterForDaysAgo(int daysAgo) =>
            $" WHERE date(StartTime) = date('now', '-{daysAgo} day', 'localtime') ";

        public List<CategoryRule> GetCategoryRules()
        {
            var list = new List<CategoryRule>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "SELECT Id, Pattern, Category, Priority FROM CategoryRules ORDER BY Priority DESC, Pattern ASC;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new CategoryRule
                {
                    Id = reader.GetInt32(0),
                    Pattern = reader.GetString(1),
                    Category = (UsageCategory)reader.GetInt32(2),
                    Priority = reader.GetInt32(3)
                });
            }
            return list;
        }

        public void AddCategoryRule(string pattern, UsageCategory category, int priority = 50)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            InsertCategoryRule(conn, pattern.Trim(), category, priority);
        }

        public void DeleteCategoryRule(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM CategoryRules WHERE Id = @Id;", conn);
            cmd.Parameters.AddWithValue("@Id", id);
            cmd.ExecuteNonQuery();
        }

        public void UpdateCategoryRule(CategoryRule rule)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "UPDATE CategoryRules SET Category = @Category WHERE Id = @Id;", conn);
            cmd.Parameters.AddWithValue("@Id", rule.Id);
            cmd.Parameters.AddWithValue("@Category", (int)rule.Category);
            cmd.ExecuteNonQuery();
        }

        public void ResetCategoryRulesToDefaults()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            Execute(conn, "DELETE FROM CategoryRules;");
            SeedDefaultCategoryRulesIfEmpty(conn);
        }

        private static void InsertCategoryRule(SqliteConnection conn, string pattern, UsageCategory category, int priority)
        {
            using var cmd = new SqliteCommand(@"
                INSERT INTO CategoryRules (Pattern, Category, Priority) VALUES (@Pattern, @Category, @Priority);", conn);
            cmd.Parameters.AddWithValue("@Pattern", pattern);
            cmd.Parameters.AddWithValue("@Category", (int)category);
            cmd.Parameters.AddWithValue("@Priority", priority);
            cmd.ExecuteNonQuery();
        }

        // StartTime yerel saat metni olarak saklanır; bu yüzden 'localtime' 'start of day'den ÖNCE gelmeli
        // (aksi halde gün sınırı UTC gece yarısına göre hesaplanır ve kayıtlar yanlış güne düşer).
        private static string GetDateFilterClause(int filterDays) => filterDays switch
        {
            0 => " WHERE StartTime >= datetime('now', 'localtime', 'start of day') ",
            1 => " WHERE StartTime >= datetime('now', 'localtime', '-1 day', 'start of day') AND StartTime < datetime('now', 'localtime', 'start of day') ",
            7 => " WHERE StartTime >= datetime('now', 'localtime', '-7 days', 'start of day') ",
            _ => " WHERE StartTime >= datetime('now', 'localtime', 'start of day') "
        };

        private void SeedDefaultFocusGoalsIfEmpty(SqliteConnection conn)
        {
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM FocusGoals;", conn);
            if (Convert.ToInt32(countCmd.ExecuteScalar()) > 0) return;

            AddFocusGoal(conn, "Kodlama", "code", 240, UsageCategory.Productive, true);
            AddFocusGoal(conn, "Derin çalışma", "devenv", 180, UsageCategory.Productive, true);
        }

        private static void AddFocusGoal(SqliteConnection conn, string title, string pattern, int targetMinutes,
            UsageCategory? category, bool notify)
        {
            using var cmd = new SqliteCommand(@"
                INSERT INTO FocusGoals (Title, MatchPattern, TargetMinutes, RequiredCategory, NotifyOnComplete, IsEnabled)
                VALUES (@Title, @Pattern, @Target, @Category, @Notify, 1);", conn);
            cmd.Parameters.AddWithValue("@Title", title);
            cmd.Parameters.AddWithValue("@Pattern", pattern);
            cmd.Parameters.AddWithValue("@Target", targetMinutes);
            cmd.Parameters.AddWithValue("@Category", category.HasValue ? (int)category.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@Notify", notify ? 1 : 0);
            cmd.ExecuteNonQuery();
        }

        public List<FocusGoal> GetFocusGoals()
        {
            var list = new List<FocusGoal>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "SELECT Id, Title, MatchPattern, TargetMinutes, RequiredCategory, NotifyOnComplete, IsEnabled FROM FocusGoals ORDER BY Id;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new FocusGoal
                {
                    Id = reader.GetInt32(0),
                    Title = reader.GetString(1),
                    MatchPattern = reader.GetString(2),
                    TargetMinutes = reader.GetInt32(3),
                    RequiredCategory = reader.IsDBNull(4) ? null : (UsageCategory)reader.GetInt32(4),
                    NotifyOnComplete = reader.GetInt32(5) == 1,
                    IsEnabled = reader.GetInt32(6) == 1
                });
            }
            return list;
        }

        public void AddFocusGoal(FocusGoal goal)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            AddFocusGoal(conn, goal.Title, goal.MatchPattern, goal.TargetMinutes, goal.RequiredCategory, goal.NotifyOnComplete);
        }

        public void UpdateFocusGoal(FocusGoal goal)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(@"
                UPDATE FocusGoals SET Title=@Title, MatchPattern=@Pattern, TargetMinutes=@Target,
                RequiredCategory=@Category, NotifyOnComplete=@Notify, IsEnabled=@Enabled
                WHERE Id=@Id;", conn);
            cmd.Parameters.AddWithValue("@Id", goal.Id);
            cmd.Parameters.AddWithValue("@Title", goal.Title);
            cmd.Parameters.AddWithValue("@Pattern", goal.MatchPattern);
            cmd.Parameters.AddWithValue("@Target", goal.TargetMinutes);
            cmd.Parameters.AddWithValue("@Category", goal.RequiredCategory.HasValue ? (int)goal.RequiredCategory.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@Notify", goal.NotifyOnComplete ? 1 : 0);
            cmd.Parameters.AddWithValue("@Enabled", goal.IsEnabled ? 1 : 0);
            cmd.ExecuteNonQuery();
        }

        public void DeleteFocusGoal(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM FocusGoals WHERE Id=@Id;", conn);
            cmd.Parameters.AddWithValue("@Id", id);
            cmd.ExecuteNonQuery();
        }

        public int GetTodaySecondsForGoal(FocusGoal goal, Func<string, UsageCategory> categorize)
        {
            var summary = GetAppUsageSummary(0);
            int total = 0;
            foreach (var item in summary)
            {
                if (!item.ProcessName.Contains(goal.MatchPattern, StringComparison.OrdinalIgnoreCase))
                    continue;
                if (goal.RequiredCategory.HasValue && categorize(item.ProcessName) != goal.RequiredCategory.Value)
                    continue;
                total += item.TotalSeconds;
            }
            return total;
        }

        public bool WasGoalNotifiedToday(int goalId)
        {
            string today = DateTime.Now.ToString("yyyy-MM-dd");
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "SELECT COUNT(*) FROM GoalNotifications WHERE GoalId=@Id AND NotifiedDate=@Date;", conn);
            cmd.Parameters.AddWithValue("@Id", goalId);
            cmd.Parameters.AddWithValue("@Date", today);
            return Convert.ToInt32(cmd.ExecuteScalar()) > 0;
        }

        public void MarkGoalNotifiedToday(int goalId)
        {
            string today = DateTime.Now.ToString("yyyy-MM-dd");
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand(
                "INSERT OR IGNORE INTO GoalNotifications (GoalId, NotifiedDate) VALUES (@Id, @Date);", conn);
            cmd.Parameters.AddWithValue("@Id", goalId);
            cmd.Parameters.AddWithValue("@Date", today);
            cmd.ExecuteNonQuery();
        }

        public void SaveWebDomainUsage(string domain, string pageTitle, DateTime start, DateTime end, int durationSeconds)
        {
            if (durationSeconds <= 0 || string.IsNullOrWhiteSpace(domain)) return;

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            foreach (var (s, e, d) in SplitAtMidnight(start, end, durationSeconds))
            {
                using var cmd = new SqliteCommand(@"
                    INSERT INTO WebDomainUsage (Domain, PageTitle, StartTime, EndTime, DurationSeconds)
                    VALUES (@Domain, @Title, @Start, @End, @Duration);", conn);
                cmd.Parameters.AddWithValue("@Domain", domain);
                cmd.Parameters.AddWithValue("@Title", pageTitle);
                cmd.Parameters.AddWithValue("@Start", Fmt(s));
                cmd.Parameters.AddWithValue("@End", Fmt(e));
                cmd.Parameters.AddWithValue("@Duration", d);
                cmd.ExecuteNonQuery();
            }
        }

        public List<WebDomainSummary> GetWebDomainSummary(int filterDays)
        {
            var list = new List<WebDomainSummary>();
            string dateFilter = GetDateFilterClause(filterDays).Replace("StartTime", "WebDomainUsage.StartTime");

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT Domain, SUM(DurationSeconds) as TotalSec
                FROM WebDomainUsage
                {dateFilter}
                GROUP BY Domain
                ORDER BY TotalSec DESC
                LIMIT 20;", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new WebDomainSummary
                {
                    Domain = reader.GetString(0),
                    TotalSeconds = reader.GetInt32(1)
                });
            }
            return list;
        }

        public List<WebDomainSummary> GetWebDomainSummaryForDaysAgo(int daysAgo)
        {
            var list = new List<WebDomainSummary>();
            string dateFilter = GetDateFilterForDaysAgo(daysAgo).Replace("StartTime", "WebDomainUsage.StartTime");

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT Domain, SUM(DurationSeconds) as TotalSec
                FROM WebDomainUsage
                {dateFilter}
                GROUP BY Domain
                ORDER BY TotalSec DESC
                LIMIT 12;", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new WebDomainSummary
                {
                    Domain = reader.GetString(0),
                    TotalSeconds = reader.GetInt32(1)
                });
            }
            return list;
        }

        public void ImportActivityWatchEvents(IEnumerable<ActivityWatchEvent> events)
        {
            foreach (var ev in events)
            {
                if (ev.Duration <= 0) continue;
                var start = ev.Timestamp;
                var end = start.AddSeconds(ev.Duration);
                string app = ev.App ?? "unknown";
                string title = string.IsNullOrEmpty(ev.Url) ? (ev.Title ?? "") : ev.Url;
                SaveUsageRecord(app, title, start, end, (int)ev.Duration);
            }
        }

        public Dictionary<int, int> GetHourlyUsageSummary(int filterDays = 0)
        {
            var summary = new Dictionary<int, int>();
            for (int i = 0; i < 24; i++)
                summary[i] = 0;

            string dateFilterClause = GetDateFilterClause(filterDays);

            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand($@"
                SELECT CAST(strftime('%H', StartTime) AS INTEGER) as Hour, SUM(DurationSeconds)
                FROM WindowUsage
                {dateFilterClause}
                GROUP BY Hour;", conn);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                int hour = reader.GetInt32(0);
                int seconds = reader.GetInt32(1);
                if (hour >= 0 && hour < 24)
                    summary[hour] = seconds;
            }
            return summary;
        }
    }

    public class AppUsageData
    {
        public required string ProcessName { get; set; }
        public int TotalSeconds { get; set; }
    }

    public class UsageRecord
    {
        public required string ProcessName { get; set; }
        public required string WindowTitle { get; set; }
        public required string StartTime { get; set; }
        public required string EndTime { get; set; }
        public int DurationSeconds { get; set; }
    }

    public class DailyUsageData
    {
        public required string Day { get; set; }
        public int TotalSeconds { get; set; }
    }

    public class WebDomainSummary
    {
        public required string Domain { get; set; }
        public int TotalSeconds { get; set; }
    }

}
