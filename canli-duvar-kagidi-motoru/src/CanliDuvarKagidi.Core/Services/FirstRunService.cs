using System.Text.Json;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public sealed class FirstRunService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private readonly AppPaths _paths;
    private readonly InstalledWallpaperService _installed;

    public FirstRunService(AppPaths paths, InstalledWallpaperService installed)
    {
        _paths = paths;
        _installed = installed;
    }

    public bool IsFirstRun() => !File.Exists(Path.Combine(_paths.Root, ".initialized"));

    public void MarkInitialized() =>
        File.WriteAllText(Path.Combine(_paths.Root, ".initialized"), DateTimeOffset.UtcNow.ToString("O"));

    public async Task InstallBundledSamplesAsync(CancellationToken ct = default)
    {
        if (!CatalogUrlResolver.TryGetLocalIndexPath(CatalogUrlResolver.GetBundledIndexPath(), out var indexPath))
            return;

        var json = await File.ReadAllTextAsync(indexPath, ct);
        var index = JsonSerializer.Deserialize<CatalogIndex>(json, JsonOptions);
        if (index?.Wallpapers is not { Count: > 0 })
            return;

        var baseDir = CatalogUrlResolver.GetLocalBaseDirectory(indexPath);
        foreach (var entry in index.Wallpapers)
        {
            if (_installed.IsInstalled(entry.Id))
                continue;

            var zipPath = Path.Combine(baseDir, entry.PackageUrl.Replace('/', Path.DirectorySeparatorChar));
            if (!File.Exists(zipPath))
                continue;

            try
            {
                await InstallFromLocalZipAsync(entry, zipPath, ct);
            }
            catch
            {
                // optional samples — skip failures
            }
        }
    }

    private async Task InstallFromLocalZipAsync(CatalogEntry entry, string zipPath, CancellationToken ct)
    {
        var extractDir = Path.Combine(_paths.Cache, "first-run", entry.Id, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(extractDir);

        try
        {
            System.IO.Compression.ZipFile.ExtractToDirectory(zipPath, extractDir, overwriteFiles: true);
            var manifestPath = Path.Combine(extractDir, "manifest.json");
            if (!File.Exists(manifestPath))
                return;

            var manifestJson = await File.ReadAllTextAsync(manifestPath, ct);
            var manifest = JsonSerializer.Deserialize<WallpaperManifest>(manifestJson, JsonOptions);
            if (manifest == null)
                return;

            manifest.Id = entry.Id;
            manifest.Title = string.IsNullOrWhiteSpace(manifest.Title) ? entry.Title : manifest.Title;
            manifest.Version = entry.Version;
            await File.WriteAllTextAsync(manifestPath, JsonSerializer.Serialize(manifest, JsonOptions), ct);
            _installed.InstallFromDirectory(extractDir, entry.Id);
        }
        finally
        {
            if (Directory.Exists(extractDir))
                Directory.Delete(extractDir, recursive: true);
        }
    }
}
