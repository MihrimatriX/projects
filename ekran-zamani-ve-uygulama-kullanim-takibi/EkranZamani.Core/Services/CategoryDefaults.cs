using EkranZamani.Models;

namespace EkranZamani.Services;

public static class CategoryDefaults
{
    public static UsageCategory GetCategory(string processName)
    {
        var p = processName.ToLowerInvariant();

        if (ContainsAny(p, "steam", "epicgameslauncher", "gog", "battle.net", "riotclient",
                "gta", "minecraft", "valorant", "league", "dota2", "fortnite"))
            return UsageCategory.Distracting;

        if (ContainsAny(p, "discord", "telegram", "whatsapp", "instagram", "tiktok",
                "facebook", "twitter", "xbox", "netflix", "spotify", "vlc", "wmplayer"))
            return UsageCategory.Distracting;

        if (ContainsAny(p, "slack", "teams", "zoom", "skype", "outlook"))
            return UsageCategory.Communication;

        if (ContainsAny(p, "devenv", "code", "rider", "visualstudio", "sublime", "notepad++",
                "obsidian", "figma", "postman", "docker", "wt", "powershell", "cmd", "bash",
                "terminal", "windows terminal"))
            return UsageCategory.Productive;

        if (ContainsAny(p, "word", "excel", "powerpnt", "onenote", "notion", "acrobat", "winword"))
            return UsageCategory.Productive;

        if (ContainsAny(p, "chrome", "firefox", "msedge", "edge", "opera", "brave"))
            return UsageCategory.Neutral;

        return UsageCategory.Neutral;
    }

    public static string GetLabel(UsageCategory category) => category switch
    {
        UsageCategory.Productive => "Verimli",
        UsageCategory.Distracting => "Dikkat dağıtıcı",
        UsageCategory.Communication => "İletişim",
        _ => "Nötr"
    };

    private static bool ContainsAny(string haystack, params string[] needles)
    {
        foreach (var n in needles)
        {
            if (haystack.Contains(n))
                return true;
        }
        return false;
    }
}
