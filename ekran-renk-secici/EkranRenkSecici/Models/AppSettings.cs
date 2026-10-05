namespace EkranRenkSecici.Models;

public enum CopyFormat
{
    HEX,
    RGB,
    HSL,
    OKLCH,
    CSS
}

public sealed class AppSettings
{
    public string HotkeyKey { get; set; } = "C";
    public string HotkeyModifiers { get; set; } = "Control,Shift";
    public CopyFormat DefaultCopyFormat { get; set; } = CopyFormat.HEX;
    public int SampleSize { get; set; } = 3;
    public int MagnifierZoom { get; set; } = 8;
}
