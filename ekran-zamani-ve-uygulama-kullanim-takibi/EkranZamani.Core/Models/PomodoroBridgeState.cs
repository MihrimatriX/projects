namespace EkranZamani.Models
{
    public class PomodoroBridgeState
    {
        public string Phase { get; set; } = "idle";
        public int RemainingSeconds { get; set; }
        public int CompletedFocusSessions { get; set; }
        public string? ActiveApp { get; set; }
        public bool IsTracking { get; set; }
        public DateTime LastUpdated { get; set; }
    }
}
