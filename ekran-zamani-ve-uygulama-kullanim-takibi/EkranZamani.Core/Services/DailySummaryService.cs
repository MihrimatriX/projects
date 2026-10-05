using System;
using System.Linq;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class DailySummaryService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public DailySummaryService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public string? TryBuildTodaySummary(AppSettings settings)
        {
            if (!settings.EnableDailySummary) return null;

            var now = DateTime.Now;
            if (now.Hour < settings.DailySummaryHour) return null;

            string today = now.ToString("yyyy-MM-dd");
            if (settings.LastDailySummaryDate == today) return null;

            int total = _db.GetAppUsageSummary(0).Sum(a => a.TotalSeconds);
            int productive = _db.GetCategorySecondsForDay(0, UsageCategory.Productive, _categories.GetCategory);
            int distracting = _db.GetCategorySecondsForDay(0, UsageCategory.Distracting, _categories.GetCategory);

            settings.LastDailySummaryDate = today;

            return $"Bugün {FormatShort(total)} ekran · Verimli {FormatShort(productive)} · Dikkat {FormatShort(distracting)}";
        }

        private static string FormatShort(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            if (t.TotalHours >= 1)
                return $"{(int)t.TotalHours} sa {t.Minutes} dk";
            return $"{t.Minutes} dk";
        }
    }
}
