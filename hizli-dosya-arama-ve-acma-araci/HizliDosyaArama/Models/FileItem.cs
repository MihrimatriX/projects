using System.IO;
using HizliDosyaArama.Helpers;

namespace HizliDosyaArama.Models;

public class FileItem
{
    public string FileName { get; }
    public string FilePath { get; }
    public string Extension { get; }
    public DateTime LastWriteTime { get; }

    public FileIconKind IconKind { get; }
    public string ExtensionBadge => string.IsNullOrEmpty(Extension) ? string.Empty : Extension;
    public string RelativeTime => FileHelper.FormatRelativeTime(LastWriteTime);
    public string ShortPath => FileHelper.ShortenPath(Path.GetDirectoryName(FilePath) ?? string.Empty);
    public bool IsRecent { get; init; }

    public string NameBefore { get; private set; }
    public string NameHighlight { get; private set; } = string.Empty;
    public string NameAfter { get; private set; }
    public bool HasHighlight { get; private set; }

    public FileItem(string fileName, string filePath, string extension, DateTime lastWriteTime, string? query = null, bool isRecent = false)
    {
        FileName = fileName;
        FilePath = filePath;
        Extension = extension;
        LastWriteTime = lastWriteTime;
        IconKind = FileHelper.GetIconKind(extension);
        IsRecent = isRecent;
        FileHelper.ApplyHighlight(fileName, query, out var before, out var highlight, out var after);
        NameBefore = before;
        NameHighlight = highlight ?? string.Empty;
        NameAfter = after;
        HasHighlight = !string.IsNullOrEmpty(highlight);
    }
}
