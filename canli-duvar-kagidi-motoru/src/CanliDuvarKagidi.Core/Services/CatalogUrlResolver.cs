namespace CanliDuvarKagidi.Core.Services;

public static class CatalogUrlResolver
{
    public const string BundledToken = "bundled";

    public static string GetDefaultCatalogUrl()
    {
        var bundled = GetBundledIndexPath();
        return File.Exists(bundled) ? bundled : "http://localhost:8080/index.json";
    }

    public static string GetBundledIndexPath() =>
        Path.Combine(AppContext.BaseDirectory, "catalog", "index.json");

    public static string Resolve(string? catalogUrl)
    {
        if (string.IsNullOrWhiteSpace(catalogUrl) ||
            string.Equals(catalogUrl.Trim(), BundledToken, StringComparison.OrdinalIgnoreCase))
        {
            return GetDefaultCatalogUrl();
        }

        return catalogUrl.Trim();
    }

    /// <summary>Ayarlar ekranindaki girdi: "bundled", http(s) adresi, file:// ya da tam yerel yol.</summary>
    public static bool IsValidSetting(string? catalogUrl)
    {
        var value = catalogUrl?.Trim();
        if (string.IsNullOrEmpty(value) || string.Equals(value, BundledToken, StringComparison.OrdinalIgnoreCase))
            return true;
        if (Uri.TryCreate(value, UriKind.Absolute, out var uri))
            return uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps || uri.IsFile;
        return false;
    }

    public static bool TryGetLocalIndexPath(string catalogUrl, out string indexPath)
    {
        indexPath = string.Empty;
        var resolved = Resolve(catalogUrl);

        if (resolved.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            resolved.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var candidate = resolved.StartsWith("file://", StringComparison.OrdinalIgnoreCase)
            ? new Uri(resolved).LocalPath
            : Path.GetFullPath(resolved);

        if (!File.Exists(candidate))
            return false;

        indexPath = candidate;
        return true;
    }

    public static string GetLocalBaseDirectory(string indexPath) =>
        Path.GetDirectoryName(indexPath) ?? AppContext.BaseDirectory;
}
