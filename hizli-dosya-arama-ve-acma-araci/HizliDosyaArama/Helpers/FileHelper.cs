using System;
using System.IO;

namespace HizliDosyaArama.Helpers;

public enum FileIconKind
{
    Doc,
    Code,
    Folder,
    Config
}

public static class FileHelper
{
    private static readonly HashSet<string> CodeExtensions =
    [
        "cs", "java", "py", "js", "ts", "tsx", "jsx", "cpp", "c", "h", "html", "css",
        "php", "go", "rs", "sh", "bat", "ps1", "xaml", "vue", "svelte", "rb", "swift", "kt"
    ];

    private static readonly HashSet<string> DocExtensions =
    [
        "pdf", "doc", "docx", "rtf", "odt", "xls", "xlsx", "ods", "csv", "ppt", "pptx",
        "odp", "txt", "md", "log"
    ];

    private static readonly HashSet<string> ConfigExtensions =
    [
        "json", "yaml", "yml", "xml", "ini", "toml", "csproj", "sln", "props", "targets", "config"
    ];

    public static FileIconKind GetIconKind(string extension)
    {
        var ext = extension.TrimStart('.').ToLowerInvariant();
        if (string.IsNullOrEmpty(ext)) return FileIconKind.Folder;
        if (CodeExtensions.Contains(ext)) return FileIconKind.Code;
        if (ConfigExtensions.Contains(ext)) return FileIconKind.Config;
        if (DocExtensions.Contains(ext)) return FileIconKind.Doc;
        return FileIconKind.Doc;
    }

    public static string FormatRelativeTime(DateTime time)
    {
        var delta = DateTime.Now - time;
        if (delta.TotalMinutes < 1) return "az önce";
        if (delta.TotalMinutes < 60) return $"{(int)delta.TotalMinutes} dk önce";
        if (delta.TotalHours < 24) return delta.TotalHours < 2 ? "1 saat önce" : $"{(int)delta.TotalHours} saat önce";
        if (delta.TotalDays < 2) return "dün";
        if (delta.TotalDays < 7) return $"{(int)delta.TotalDays} gün önce";
        return time.ToString("dd.MM.yyyy");
    }

    public static string ShortenPath(string fullPath, int tailLength = 48)
    {
        if (string.IsNullOrEmpty(fullPath)) return string.Empty;
        if (fullPath.Length <= tailLength) return fullPath;
        return "..." + fullPath[^tailLength..];
    }

    public static void ApplyHighlight(string fileName, string? query, out string before, out string? highlight, out string after)
    {
        before = fileName;
        highlight = null;
        after = string.Empty;

        if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
            return;

        var source = fileName;
        var index = source.IndexOf(query, StringComparison.OrdinalIgnoreCase);
        if (index < 0) return;

        before = source[..index];
        highlight = source.Substring(index, query.Length);
        after = source[(index + query.Length)..];
    }
}
