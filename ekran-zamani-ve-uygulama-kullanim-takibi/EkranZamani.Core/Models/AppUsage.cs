using System;
using EkranZamani.Helpers;
using EkranZamani.Services;

namespace EkranZamani.Models
{
    public class AppUsage
    {
        public string ProcessName { get; }
        public int TotalSeconds { get; set; }
        public double Percentage { get; set; }
        public UsageCategory ProductivityCategory { get; }

        public AppUsage(string processName, int totalSeconds, UsageCategory? category = null)
        {
            ProcessName = processName;
            TotalSeconds = totalSeconds;
            ProductivityCategory = category ?? AppServices.Categories.GetCategory(processName);
        }

        public string DisplayName => ProcessDisplayNames.GetFriendlyName(ProcessName);

        public string CategoryLabel => CategoryService.GetLabel(ProductivityCategory);

        public string Icon => ProcessName.ToLower() switch
        {
            var p when p.Contains("chrome") || p.Contains("firefox") || p.Contains("edge") || p.Contains("opera") || p.Contains("brave") => "🌐",
            var p when p.Contains("devenv") || p.Contains("code") || p.Contains("rider") || p.Contains("visualstudio") || p.Contains("sublime") => "💻",
            var p when p.Contains("notepad") || p.Contains("word") || p.Contains("excel") || p.Contains("powerpnt") || p.Contains("acrobat") => "📝",
            var p when p.Contains("discord") || p.Contains("slack") || p.Contains("teams") || p.Contains("zoom") || p.Contains("telegram") || p.Contains("whatsapp") => "💬",
            var p when p.Contains("spotify") || p.Contains("vlc") || p.Contains("wmplayer") || p.Contains("youtube") || p.Contains("netflix") => "🎵",
            var p when p.Contains("explorer") => "📂",
            var p when p.Contains("steam") || p.Contains("epicgames") || p.Contains("gta") || p.Contains("game") => "🎮",
            var p when p.Contains("cmd") || p.Contains("powershell") || p.Contains("wt") || p.Contains("bash") => "🖥️",
            _ => "⚙️"
        };

        public string FormattedTime
        {
            get
            {
                TimeSpan t = TimeSpan.FromSeconds(TotalSeconds);
                if (t.TotalHours >= 1)
                    return $"{(int)t.TotalHours} sa {t.Minutes} dk";
                if (t.TotalMinutes >= 1)
                    return $"{t.Minutes} dk {t.Seconds} sn";
                return $"{t.Seconds} sn";
            }
        }
    }
}
