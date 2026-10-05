namespace SistemYoneticisi.Helpers;

public static class FormatHelpers
{
    public static string FormatSpeed(double kbps)
    {
        if (kbps >= 1024)
            return string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0:F1} Mbps", kbps / 1024.0);
        return string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0:F0} Kbps", kbps);
    }

    public static string FormatDiskSummary(double usedGb, double totalGb)
        => string.Format(System.Globalization.CultureInfo.InvariantCulture,
            "{0:F1} GB kullanıldı / {1:F1} GB", usedGb, totalGb);
}
