namespace EkranZamani.Services;

public static class SensitiveAppFilter
{
    private static readonly string[] BlockedProcessFragments =
    {
        "1password", "bitwarden", "keepass", "lastpass", "dashlane",
        "nordpass", "enpass", "roboform", "authy", "winauth"
    };

    private static readonly string[] RedactedTitleOnlyFragments =
    {
        "bank", "banka", "garanti", "akbank", "yapikredi", "isbank",
        "ziraat", "vakif", "halkbank", "qnb", "enpara"
    };

    public static bool ShouldSkipLogging(string processName, IEnumerable<string>? userBlacklist = null)
    {
        var p = processName.ToLowerInvariant();
        foreach (var fragment in BlockedProcessFragments)
        {
            if (p.Contains(fragment))
                return true;
        }

        if (userBlacklist == null)
            return false;

        foreach (var entry in userBlacklist)
        {
            if (MatchesPattern(p, entry))
                return true;
        }

        return false;
    }

    public static string SanitizeTitle(string processName, string windowTitle)
    {
        if (ShouldSkipLogging(processName))
            return string.Empty;

        var p = processName.ToLowerInvariant();
        foreach (var fragment in RedactedTitleOnlyFragments)
        {
            if (p.Contains(fragment))
                return "[Gizli]";
        }

        return windowTitle;
    }

    public static bool IsValidBlacklistEntry(string entry)
    {
        if (string.IsNullOrWhiteSpace(entry))
            return false;
        var trimmed = entry.Trim();
        return trimmed.Length >= 2 && !trimmed.Contains(' ');
    }

    private static bool MatchesPattern(string processLower, string pattern)
    {
        if (string.IsNullOrWhiteSpace(pattern))
            return false;

        var needle = pattern.Trim().ToLowerInvariant().Replace("\\", "/");
        if (needle.EndsWith(".exe", StringComparison.Ordinal))
            needle = needle[..^4];

        return processLower.Contains(needle, StringComparison.Ordinal);
    }
}
