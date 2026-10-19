using System.Text.Json;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public sealed class InstalledWallpaperService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private readonly AppPaths _paths;

    public InstalledWallpaperService(AppPaths paths) => _paths = paths;

    // Id uzak katalogdan gelir ve hedef klasor recursive silinir; "..\.." gibi id'ler
    // installed\ disina tasmasin diye yalnizca tek bir klasor adi kabul edilir.
    public string GetPackagePath(string wallpaperId)
    {
        if (string.IsNullOrWhiteSpace(wallpaperId) || wallpaperId is "." or ".." ||
            wallpaperId != Path.GetFileName(wallpaperId) ||
            wallpaperId.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
            throw new InvalidOperationException($"Gecersiz duvar kagidi id: {wallpaperId}");

        return Path.Combine(_paths.Installed, wallpaperId);
    }

    public bool IsInstalled(string wallpaperId) =>
        Directory.Exists(GetPackagePath(wallpaperId)) &&
        File.Exists(Path.Combine(GetPackagePath(wallpaperId), "manifest.json"));

    public IReadOnlyList<WallpaperManifest> ListInstalled()
    {
        if (!Directory.Exists(_paths.Installed))
            return [];

        var results = new List<WallpaperManifest>();
        foreach (var dir in Directory.GetDirectories(_paths.Installed))
        {
            var manifestPath = Path.Combine(dir, "manifest.json");
            if (!File.Exists(manifestPath))
                continue;

            try
            {
                var json = File.ReadAllText(manifestPath);
                var manifest = JsonSerializer.Deserialize<WallpaperManifest>(json, JsonOptions);
                if (manifest != null)
                    results.Add(manifest);
            }
            catch
            {
                // skip corrupt packages
            }
        }

        return results.OrderBy(w => w.Title).ToList();
    }

    public WallpaperManifest? LoadManifest(string wallpaperId)
    {
        var manifestPath = Path.Combine(GetPackagePath(wallpaperId), "manifest.json");
        if (!File.Exists(manifestPath))
            return null;

        var json = File.ReadAllText(manifestPath);
        return JsonSerializer.Deserialize<WallpaperManifest>(json, JsonOptions);
    }

    public void InstallFromDirectory(string sourceDirectory, string wallpaperId)
    {
        var target = GetPackagePath(wallpaperId);
        if (Directory.Exists(target))
            Directory.Delete(target, recursive: true);

        CopyDirectory(sourceDirectory, target);
    }

    // Image.FromFile ve WebView2 <video> ile oynatilabilen bicimler
    public static readonly IReadOnlyDictionary<string, string> ImportableExtensions =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [".png"] = "image", [".jpg"] = "image", [".jpeg"] = "image", [".bmp"] = "image", [".gif"] = "image",
            [".mp4"] = "video", [".webm"] = "video"
        };

    /// <summary>Kullanicinin kendi gorsel/video dosyasini kutuphaneye paket olarak ekler.</summary>
    public WallpaperManifest ImportFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException("Dosya bulunamadi.", filePath);

        var ext = Path.GetExtension(filePath);
        if (!ImportableExtensions.TryGetValue(ext, out var type))
            throw new InvalidOperationException(
                $"Desteklenmeyen dosya turu: {ext}. Desteklenenler: {string.Join(", ", ImportableExtensions.Keys)}");

        var title = Path.GetFileNameWithoutExtension(filePath);
        var baseId = "yerel-" + Slug(title);
        var id = baseId;
        for (var i = 2; Directory.Exists(GetPackagePath(id)); i++)
            id = $"{baseId}-{i}";

        var manifest = new WallpaperManifest
        {
            Id = id,
            Title = title,
            Type = type,
            Entry = "wallpaper" + ext.ToLowerInvariant(),
            Description = "Yerel dosyadan eklendi."
        };

        var target = GetPackagePath(id);
        Directory.CreateDirectory(target);
        try
        {
            File.Copy(filePath, manifest.ResolveEntryPath(target));
            File.WriteAllText(Path.Combine(target, "manifest.json"), JsonSerializer.Serialize(manifest));
        }
        catch
        {
            Directory.Delete(target, recursive: true); // yarim paket kutuphanede kalmasin
            throw;
        }

        return manifest;
    }

    private static string Slug(string text)
    {
        // FormD ile "ş" -> "s" + isaret; isaret atilir, kalan ASCII disi karakterler tire olur
        var chars = text.ToLowerInvariant().Replace('ı', 'i').Normalize(System.Text.NormalizationForm.FormD)
            .Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) !=
                        System.Globalization.UnicodeCategory.NonSpacingMark)
            .Select(c => char.IsAsciiLetterOrDigit(c) ? c : '-')
            .ToArray();
        var slug = string.Join('-', new string(chars).Split('-', StringSplitOptions.RemoveEmptyEntries));
        return slug.Length == 0 ? "duvar-kagidi" : slug[..Math.Min(slug.Length, 40)];
    }

    public void Uninstall(string wallpaperId)
    {
        var target = GetPackagePath(wallpaperId);
        if (Directory.Exists(target))
            Directory.Delete(target, recursive: true);
    }

    private static void CopyDirectory(string source, string target)
    {
        Directory.CreateDirectory(target);
        foreach (var file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
        {
            var relative = Path.GetRelativePath(source, file);
            var dest = Path.Combine(target, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
            File.Copy(file, dest, overwrite: true);
        }
    }
}
