using System;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class UsageAlertService
    {
        public event Action<int>? DistractingLimitExceeded;

        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public UsageAlertService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public void CheckDistractingLimit(AppSettings settings)
        {
            if (!settings.EnableDistractingAlert || settings.DistractingLimitMinutes <= 0)
                return;

            string today = DateTime.Now.ToString("yyyy-MM-dd");
            if (settings.LastDistractingAlertDate == today)
                return;

            int limitSeconds = settings.DistractingLimitMinutes * 60;
            int distracting = _db.GetCategorySecondsForDay(0, UsageCategory.Distracting, _categories.GetCategory);

            if (distracting < limitSeconds)
                return;

            settings.LastDistractingAlertDate = today;
            DistractingLimitExceeded?.Invoke(settings.DistractingLimitMinutes);
        }
    }
}
