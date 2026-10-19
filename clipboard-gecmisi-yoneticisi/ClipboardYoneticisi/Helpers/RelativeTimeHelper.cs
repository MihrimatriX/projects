namespace ClipboardYoneticisi.Helpers;

public static class RelativeTimeHelper
{
    public static string Format(DateTime timestamp)
    {
        var diff = DateTime.Now - timestamp;
        if (diff.TotalSeconds < 45) return "az önce";
        if (diff.TotalMinutes < 60) return $"{(int)diff.TotalMinutes} dk";
        if (diff.TotalHours < 24) return $"{(int)diff.TotalHours} sa";
        if (diff.TotalDays < 7) return $"{(int)diff.TotalDays} gün";
        return timestamp.ToString("dd.MM.yy");
    }
}
