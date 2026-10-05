using System.Text.Json.Serialization;

namespace CanliDuvarKagidi.Core.Models;

public sealed class WallpaperManifest
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "image";

    [JsonPropertyName("entry")]
    public string Entry { get; set; } = string.Empty;

    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0.0";

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("thumbnail")]
    public string? Thumbnail { get; set; }

    [JsonIgnore]
    public WallpaperType WallpaperType => Type.ToLowerInvariant() switch
    {
        "video" => WallpaperType.Video,
        "web" => WallpaperType.Web,
        _ => WallpaperType.Image
    };

    /// <summary>Arayuzde gosterilen Turkce tur adi.</summary>
    public static string TypeLabel(string type) => type.ToLowerInvariant() switch
    {
        "video" => "Video",
        "web" => "Web",
        _ => "Görsel"
    };

    /// <summary>Kutuphane aramasi: ad, aciklama ya da tur (Turkce/Ingilizce) icinde; buyuk/kucuk harf ve aksan duyarsiz
    /// (Turkce klavyesiz yazilan "gun batimi" da "Gün Batımı"yi bulur).</summary>
    public bool Matches(string? query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return true;

        var q = Fold(query.Trim());
        return new[] { Title, Description ?? "", Type, TypeLabel(Type) }.Any(field => Fold(field).Contains(q, StringComparison.Ordinal));
    }

    private static string Fold(string text)
    {
        var decomposed = text.Replace('ı', 'i').Replace('İ', 'i').ToLowerInvariant()
            .Normalize(System.Text.NormalizationForm.FormD);
        return new string(decomposed.Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) !=
                                                System.Globalization.UnicodeCategory.NonSpacingMark).ToArray());
    }

    public string ResolveEntryPath(string packageRoot) =>
        Path.Combine(packageRoot, Entry.Replace('/', Path.DirectorySeparatorChar));
}
