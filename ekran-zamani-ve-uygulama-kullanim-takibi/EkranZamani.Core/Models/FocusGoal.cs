namespace EkranZamani.Models
{
    public class FocusGoal
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string MatchPattern { get; set; } = string.Empty;
        public int TargetMinutes { get; set; } = 60;
        public UsageCategory? RequiredCategory { get; set; }
        public bool NotifyOnComplete { get; set; } = true;
        public bool IsEnabled { get; set; } = true;
    }
}
