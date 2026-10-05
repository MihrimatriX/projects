namespace CanliDuvarKagidi_Shell.Models;

using Microsoft.UI.Xaml;

public sealed class WallpaperListItem
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Type { get; init; }
    public required string TypeLabel { get; init; }
    public required string Version { get; init; }
    public string? Description { get; init; }
    public string Glyph => Type.ToLowerInvariant() switch
    {
        "video" => "\uE714",
        "web" => "\uE774",
        _ => "\uEB9F"
    };

    // GridViewItem'in UIA/ekran okuyucu adi veri nesnesinin ToString()'idir
    public override string ToString() => $"{Title}, {TypeLabel}";
}

public sealed class CatalogListItem
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Type { get; init; }
    public required string TypeLabel { get; init; }
    public required string Version { get; init; }
    public string? Description { get; init; }
    public string Glyph => Type.ToLowerInvariant() switch
    {
        "video" => "\uE714",
        "web" => "\uE774",
        _ => "\uEB9F"
    };

    public override string ToString() => $"{Title}, {TypeLabel}, {Version}";
}

public sealed class MonitorListItem
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required string Resolution { get; init; }
    public required string WallpaperTitle { get; init; }
    public required bool IsActive { get; init; }
    public required bool IsPrimary { get; init; }
    public Visibility ActiveBadgeVisibility => IsActive ? Visibility.Visible : Visibility.Collapsed;
    public string WallpaperDisplay => $"Duvar kağıdı: {WallpaperTitle}";
    public override string ToString() => $"{Name}, {Resolution}, {WallpaperDisplay}";
}
