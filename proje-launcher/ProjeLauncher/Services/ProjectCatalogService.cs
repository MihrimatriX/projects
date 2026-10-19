using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using ProjeLauncher.Models;

namespace ProjeLauncher.Services;

public sealed record ReadmeSummary(string Intro, IReadOnlyList<string> Features);

public static class ProjectCatalogService
{
    private static readonly Regex TitleRegex = new(@"^#\s+(.+)$", RegexOptions.Compiled);
    private static readonly HashSet<string> Skip = new(StringComparer.OrdinalIgnoreCase) { "dist", "proje-launcher" };

    public static IReadOnlyList<ProjectEntry> Load(string root)
    {
        var tr = StringComparer.Create(CultureInfo.GetCultureInfo("tr-TR"), ignoreCase: true);
        return Directory.GetDirectories(root)
            .AsParallel()
            .Select(dir => TryLoadEntry(root, dir, Path.GetFileName(dir)))
            .OfType<ProjectEntry>()
            .OrderBy(e => e.Name, tr)
            .ToList();
    }

    private static ProjectEntry? TryLoadEntry(string root, string dir, string folder)
    {
        if (folder.StartsWith('.') || Skip.Contains(folder)) return null;

        var readme = Path.Combine(dir, "README.md");
        var runPs1 = Path.Combine(dir, "run.ps1");
        if (!File.Exists(readme) && !File.Exists(runPs1)) return null;

        string? name = null, desc = null, category = null;
        string[] tags = [];
        var manifestPath = Path.Combine(dir, "assets", "manifest.json");
        if (File.Exists(manifestPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(manifestPath));
                var r = doc.RootElement;
                name = Str(r, "name");
                desc = Str(r, "description");
                category = Str(r, "category");
                if (r.TryGetProperty("tags", out var t) && t.ValueKind == JsonValueKind.Array)
                    tags = t.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String)
                        .Select(x => x.GetString()!).Where(x => x.Length > 0).ToArray();
            }
            catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException) { /* bozuk manifest: README'ye dus */ }
        }

        name ??= ReadTitle(readme) ?? folder;
        desc ??= ReadSummary(readme).Intro is { Length: > 0 } intro ? intro : null;

        // Sozlesme: <repo>\dist\<klasor>\ en ust duzeyinde tek exe (publish.ps1 uretir).
        var distDir = Path.Combine(root, "dist", folder);
        var exes = Directory.Exists(distDir) ? Directory.GetFiles(distDir, "*.exe") : [];
        var publish = Path.Combine(dir, "publish.ps1");

        return new ProjectEntry
        {
            Folder = folder,
            Name = name,
            Path = dir,
            Stack = DetectStack(dir),
            Description = desc,
            Tags = tags,
            Category = category,
            ReadmePath = readme,
            RunScript = File.Exists(runPs1) ? runPs1 : null,
            PublishScript = File.Exists(publish) ? publish : null,
            DistDir = distDir,
            ExePath = exes.Length == 1 ? exes[0] : null,
            Screenshots = FindScreenshots(dir)
        };
    }

    private static string? Str(JsonElement r, string prop) =>
        r.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String && v.GetString() is { Length: > 0 } s ? s.Trim() : null;

    internal static string[] FindScreenshots(string dir)
    {
        var docs = Path.Combine(dir, "docs");
        if (!Directory.Exists(docs)) return [];
        return Directory.GetFiles(docs, "ekran*.png")
            .OrderBy(f => Path.GetFileName(f).Equals("ekran.png", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(f => f, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string? ReadTitle(string readmePath)
    {
        if (!File.Exists(readmePath)) return null;
        foreach (var line in File.ReadLines(readmePath).Take(5))
        {
            var m = TitleRegex.Match(line);
            if (m.Success) return m.Groups[1].Value.Trim();
        }
        return null;
    }

    /// <summary>README: basliktan sonraki ilk paragraf + "Özellikler" bolumunun ilk maddeleri.</summary>
    public static ReadmeSummary ReadSummary(string readmePath, int maxFeatures = 8)
    {
        if (!File.Exists(readmePath)) return new("", []);
        string[] lines;
        try { lines = File.ReadLines(readmePath).Take(200).ToArray(); }
        catch (IOException) { return new("", []); }

        var intro = new List<string>();
        var features = new List<string>();
        bool introDone = false, inFeatures = false;
        foreach (var raw in lines)
        {
            var line = raw.Trim();
            if (line.StartsWith('#'))
            {
                if (intro.Count > 0) introDone = true;
                inFeatures = line.StartsWith("##") && TurkishText.Fold(line).Contains("ozellik");
                if (!inFeatures && features.Count > 0) break;
                continue;
            }
            if (inFeatures)
            {
                if (features.Count < maxFeatures && (line.StartsWith("- ") || line.StartsWith("* ")))
                    features.Add(CleanMarkdown(line[2..]));
                continue;
            }
            if (introDone) continue;
            if (line.Length == 0) { introDone = intro.Count > 0; continue; }
            if (line.StartsWith("![") || line.StartsWith("[![") || line.StartsWith('<')) continue;
            if (line.StartsWith("- ") || line.StartsWith("* ") || line.StartsWith("```") || line.StartsWith('|'))
            {
                introDone = intro.Count > 0;
                continue;
            }
            intro.Add(CleanMarkdown(line.TrimStart('>', ' ')));
        }
        return new(string.Join(' ', intro), features);
    }

    private static readonly Regex MdLink = new(@"\[([^\]]+)\]\([^)]*\)", RegexOptions.Compiled);
    private static string CleanMarkdown(string s) =>
        MdLink.Replace(s, "$1").Replace("**", "").Replace("`", "").Trim();

    private static ProjectStack DetectStack(string dir)
    {
        // .csproj aramasi derinlik 2 ile sinirli ve package.json olan (node_modules iceren) klasorlerde yapilmaz:
        // sinirsiz arama node_modules'u tarayip acilisi ~20 sn donduruyordu. Erisilemeyen klasorler atlanir.
        var pkg = Path.Combine(dir, "package.json");
        var csprojSearch = new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 2 };
        if (!File.Exists(pkg) && Directory.EnumerateFiles(dir, "*.csproj", csprojSearch).Any())
            return ProjectStack.Dotnet;
        if (File.Exists(Path.Combine(dir, "pubspec.yaml"))) return ProjectStack.Flutter;
        if (File.Exists(Path.Combine(dir, "main.py"))) return ProjectStack.Python;
        if (!File.Exists(pkg)) return ProjectStack.Other;

        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(pkg));
            bool Has(string name) => new[] { "dependencies", "devDependencies" }.Any(prop =>
                doc.RootElement.TryGetProperty(prop, out var deps) && deps.ValueKind == JsonValueKind.Object &&
                deps.TryGetProperty(name, out _));
            // Next.js projeleri masaustu kabugu icin electron'u da tasiyabilir; next onceliklidir.
            if (!Has("next") && Has("electron")) return ProjectStack.Electron;
        }
        catch (Exception ex) when (ex is JsonException or IOException) { }

        return ProjectStack.Node;
    }
}
