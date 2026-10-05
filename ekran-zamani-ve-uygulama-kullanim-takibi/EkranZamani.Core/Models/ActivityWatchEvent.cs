using System;

namespace EkranZamani.Models
{
    public class ActivityWatchEvent
    {
        public DateTime Timestamp { get; set; }
        public double Duration { get; set; }
        public string? App { get; set; }
        public string? Title { get; set; }
        public string? Url { get; set; }
    }
}
