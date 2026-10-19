using ProjeLauncher.Models;

namespace ProjeLauncher.Services;

public enum ScopeKind { All, Favorites, Recent, Stack, Category, Header }

public enum ExeFilter { All, HasExe, NoExe }

/// <summary>Kenar cubugu kapsami + exe filtresi + arama. Saf fonksiyon: birim testlenir.</summary>
public static class ProjectFilter
{
    public static IEnumerable<ProjectEntry> Apply(
        IEnumerable<ProjectEntry> all, ScopeKind scope, string? scopeValue,
        ExeFilter exe, string? query, IReadOnlyList<string> recent)
    {
        var items = scope switch
        {
            ScopeKind.Favorites => all.Where(p => p.IsFavorite),
            ScopeKind.Stack => all.Where(p => p.Stack.ToString() == scopeValue),
            ScopeKind.Category => all.Where(p => p.Category is not null && TurkishText.Fold(p.Category) == TurkishText.Fold(scopeValue ?? "")),
            // Son kullanilanlar: en yeni basta.
            ScopeKind.Recent => recent.Select(f => all.FirstOrDefault(p => p.Folder == f)).OfType<ProjectEntry>(),
            _ => all
        };

        if (exe == ExeFilter.HasExe) items = items.Where(p => p.HasExe);
        else if (exe == ExeFilter.NoExe) items = items.Where(p => !p.HasExe);

        var terms = TurkishText.Fold(query ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (terms.Length > 0)
            items = items.Where(p => terms.All(t => p.SearchKey.Contains(t, StringComparison.Ordinal)));

        return items;
    }
}
