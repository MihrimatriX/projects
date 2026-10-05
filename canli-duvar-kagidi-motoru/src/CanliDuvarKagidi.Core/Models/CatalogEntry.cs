using System.Text.Json.Serialization;

namespace CanliDuvarKagidi.Core.Models;

public sealed class CatalogIndex
{
    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0.0";

    [JsonPropertyName("wallpapers")]
    public List<CatalogEntry> Wallpapers { get; set; } = [];
}

public sealed class CatalogEntry
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "image";

    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0.0";

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("thumbnailUrl")]
    public string? ThumbnailUrl { get; set; }

    [JsonPropertyName("packageUrl")]
    public string PackageUrl { get; set; } = string.Empty;

    [JsonPropertyName("manifestUrl")]
    public string? ManifestUrl { get; set; }
}
