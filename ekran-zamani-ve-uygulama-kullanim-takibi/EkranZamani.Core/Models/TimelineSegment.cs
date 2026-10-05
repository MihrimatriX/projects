namespace EkranZamani.Models
{
    public class TimelineSegment
    {
        public string ProcessName { get; init; } = string.Empty;
        public string ToolTipText { get; init; } = string.Empty;
        public int DurationSeconds { get; init; }
        public double WidthWeight { get; init; }
        public double DisplayWidth { get; set; } = 4;
        public double LeftPercent { get; init; }
        public double WidthPercent { get; init; }
        public bool IsIdle { get; init; }
        public UsageCategory Category { get; init; }
        public string SegmentColorHex { get; init; } = "#8E8E93";
    }
}
