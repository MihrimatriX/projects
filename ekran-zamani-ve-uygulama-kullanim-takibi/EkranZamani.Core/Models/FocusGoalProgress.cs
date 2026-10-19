using System;

namespace EkranZamani.Models
{
    public class FocusGoalProgress
    {
        public FocusGoal Goal { get; init; } = null!;
        public int CurrentSeconds { get; set; }
        public int TargetSeconds => Goal.TargetMinutes * 60;
        public double Percentage => TargetSeconds > 0
            ? Math.Min(100, (double)CurrentSeconds / TargetSeconds * 100)
            : 0;
        public bool IsComplete => CurrentSeconds >= TargetSeconds;
        public string FormattedCurrent => Format(CurrentSeconds);
        public string FormattedTarget => Format(TargetSeconds);

        private static string Format(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            if (t.TotalHours >= 1)
                return $"{(int)t.TotalHours} sa {t.Minutes} dk";
            return $"{t.Minutes} dk";
        }
    }
}
