using System;
using System.Collections.Generic;
using System.Linq;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class FocusGoalService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public event Action<FocusGoal>? GoalCompleted;

        public FocusGoalService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public List<FocusGoalProgress> GetTodayProgress()
        {
            return _db.GetFocusGoals()
                .Where(g => g.IsEnabled)
                .Select(g => new FocusGoalProgress
                {
                    Goal = g,
                    CurrentSeconds = _db.GetTodaySecondsForGoal(g, _categories.GetCategory)
                })
                .ToList();
        }

        public void CheckAndNotify(bool notificationsEnabled)
        {
            if (!notificationsEnabled) return;

            foreach (var progress in GetTodayProgress())
            {
                if (!progress.IsComplete || !progress.Goal.NotifyOnComplete) continue;
                if (_db.WasGoalNotifiedToday(progress.Goal.Id)) continue;

                _db.MarkGoalNotifiedToday(progress.Goal.Id);
                GoalCompleted?.Invoke(progress.Goal);
            }
        }
    }
}
