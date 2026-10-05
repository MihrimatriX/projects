using System.IO.Compression;
using System.Net.Http.Json;
using System.Text.Json;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public sealed class CatalogService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private readonly HttpClient _http;
    private readonly AppPaths _paths;
    private readonly InstalledWallpaperService _installed;

    public CatalogService(HttpClient http, AppPaths paths, InstalledWallpaperService installed)
    {
        _http = http;
        _paths = paths;
        _installed = installed;
    }

    public async Task<CatalogIndex> FetchIndexAsync(string catalogUrl, CancellationToken ct = default)
    {
        var resolved = CatalogUrlResolver.Resolve(catalogUrl);

        if (CatalogUrlResolver.TryGetLocalIndexPath(resolved, out var localIndexPath))
        {
            var json = await File.ReadAllTextAsync(localIndexPath, ct);
            return JsonSerializer.Deserialize<CatalogIndex>(json, JsonOptions)
                ?? throw new InvalidOperationException("Katalog dosyasi okunamadi.");
        }

        var index = await _http.GetFromJsonAsync<CatalogIndex>(resolved, JsonOptions, ct)
            ?? throw new InvalidOperationException("Katalog bos dondu.");
        return index;
    }

    public async Task<WallpaperManifest> DownloadAndInstallAsync(
        CatalogEntry entry, string catalogBaseUrl, CancellationToken ct = default)
    {
        _installed.GetPackagePath(entry.Id); // id'yi cache yollarinda kullanmadan once dogrula
        var resolved = CatalogUrlResolver.Resolve(catalogBaseUrl);
        if (CatalogUrlResolver.TryGetLocalIndexPath(resolved, out var localIndexPath))
        {
            var baseDir = CatalogUrlResolver.GetLocalBaseDirectory(localIndexPath);
            var zipPath = Path.Combine(baseDir, entry.PackageUrl.Replace('/', Path.DirectorySeparatorChar));
            if (!File.Exists(zipPath))
                throw new FileNotFoundException("Paket dosyasi bulunamadi.", zipPath);

            return await InstallFromZipFileAsync(entry, zipPath, ct);
        }

        var baseUri = new Uri(resolved.EndsWith('/') ? resolved : resolved + "/");
        var packageUri = new Uri(baseUri, entry.PackageUrl);
        var downloadPath = Path.Combine(_paths.Cache, $"{entry.Id}-{Guid.NewGuid():N}.zip");
        try
        {
            await using (var stream = await _http.GetStreamAsync(packageUri, ct))
            await using (var file = File.Create(downloadPath))
                await stream.CopyToAsync(file, ct);

            return await InstallFromZipFileAsync(entry, downloadPath, ct);
        }
        finally
        {
            File.Delete(downloadPath); // kurulumdan sonra gereksiz; onbellekte birikmesin
        }
    }

    private async Task<WallpaperManifest> InstallFromZipFileAsync(
        CatalogEntry entry, string zipPath, CancellationToken ct)
    {
        var extractDir = Path.Combine(_paths.Cache, entry.Id, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(extractDir);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, extractDir, overwriteFiles: true);

            var manifestPath = Path.Combine(extractDir, "manifest.json");
            if (!File.Exists(manifestPath) && !string.IsNullOrWhiteSpace(entry.ManifestUrl))
            {
                var manifestJsonRemote = await _http.GetStringAsync(entry.ManifestUrl, ct);
                await File.WriteAllTextAsync(manifestPath, manifestJsonRemote, ct);
            }

            if (!File.Exists(manifestPath))
                throw new InvalidOperationException("Pakette manifest.json bulunamadi.");

            var manifestJsonLocal = await File.ReadAllTextAsync(manifestPath, ct);
            var manifest = JsonSerializer.Deserialize<WallpaperManifest>(manifestJsonLocal, JsonOptions)
                ?? throw new InvalidOperationException("manifest.json okunamadi.");

            manifest.Id = entry.Id;
            manifest.Title = string.IsNullOrWhiteSpace(manifest.Title) ? entry.Title : manifest.Title;
            manifest.Version = entry.Version;
            await File.WriteAllTextAsync(manifestPath, JsonSerializer.Serialize(manifest, JsonOptions), ct);

            _installed.InstallFromDirectory(extractDir, entry.Id);
            return manifest;
        }
        finally
        {
            if (Directory.Exists(extractDir))
                Directory.Delete(extractDir, recursive: true);
        }
    }

    public static string GetCatalogBaseUrl(string catalogUrl)
    {
        var resolved = CatalogUrlResolver.Resolve(catalogUrl);
        if (CatalogUrlResolver.TryGetLocalIndexPath(resolved, out var localIndexPath))
            return localIndexPath;

        var uri = new Uri(resolved);
        var path = uri.AbsolutePath;
        var lastSlash = path.LastIndexOf('/');
        var basePath = lastSlash >= 0 ? path[..(lastSlash + 1)] : "/";
        return $"{uri.Scheme}://{uri.Host}{(uri.IsDefaultPort ? "" : $":{uri.Port}")}{basePath}";
    }
}
