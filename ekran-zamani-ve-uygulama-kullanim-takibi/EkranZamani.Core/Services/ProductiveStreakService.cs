using System;

namespace EkranZamani.Services
{
    public class ProductiveStreakService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public ProductiveStreakService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public int ComputeStreak(int minProductiveMinutesPerDay = 30, int maxDaysToScan = 90)
        {
            int thresholdSeconds = minProductiveMinutesPerDay * 60;
            int streak = 0;

            for (int daysAgo = 0; daysAgo < maxDaysToScan; daysAgo++)
            {
                int productive = _db.GetCategorySecondsForDay(daysAgo, Models.UsageCategory.Productive, _categories.GetCategory);
                if (productive >= thresholdSeconds)
                    streak++;
                else
                    break;
            }

            return streak;
        }
    }
}
