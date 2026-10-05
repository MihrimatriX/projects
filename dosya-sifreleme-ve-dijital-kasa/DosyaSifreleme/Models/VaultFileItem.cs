namespace DosyaSifreleme.Models;

public class VaultFileItem
{
    public string Id { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public string Extension { get; set; } = string.Empty;
    public DateTime DateAdded { get; set; }

    // UIA/erişilebilirlik: liste öğesinin adı dosya adıdır (ekran okuyucu "DosyaSifreleme.Models..." okumaz).
    public override string ToString() => FileName;

    public string DisplaySize => SizeBytes switch
    {
        >= 1024 * 1024 * 1024 => $"{SizeBytes / (1024.0 * 1024.0 * 1024.0):F2} GB",
        >= 1024 * 1024 => $"{SizeBytes / (1024.0 * 1024.0):F1} MB",
        >= 1024 => $"{SizeBytes / 1024.0:F0} KB",
        _ => $"{SizeBytes} B"
    };
}
