namespace SistemYoneticisi.Services;

public class AppSettings
{
    public bool HistoryEnabled { get; set; }
    public int HistoryRetentionHours { get; set; } = 24;
    public bool AlarmsEnabled { get; set; } = true;
    public double CpuAlarmThreshold { get; set; } = 90;
    public double RamAlarmThreshold { get; set; } = 90;
    public int AlarmDurationSeconds { get; set; } = 60;
    public bool HighContrastMode { get; set; }
    public bool StartMinimized { get; set; }
    public bool RunAtLogin { get; set; }
    public bool WelcomeShown { get; set; }
    public bool GlobalHotkeyEnabled { get; set; } = true;
    public string ShowHotkey { get; set; } = "Ctrl+Shift+M";
}
