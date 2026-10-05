using System;
using System.Collections.Generic;

namespace EkranZamani.Helpers
{
    public static class ProcessDisplayNames
    {
        private static readonly Dictionary<string, string> Known = new(StringComparer.OrdinalIgnoreCase)
        {
            ["chrome"] = "Google Chrome",
            ["msedge"] = "Microsoft Edge",
            ["firefox"] = "Mozilla Firefox",
            ["brave"] = "Brave",
            ["opera"] = "Opera",
            ["devenv"] = "Visual Studio",
            ["Code"] = "VS Code",
            ["rider64"] = "JetBrains Rider",
            ["rider"] = "JetBrains Rider",
            ["powershell"] = "PowerShell",
            ["pwsh"] = "PowerShell",
            ["WindowsTerminal"] = "Terminal",
            ["wt"] = "Windows Terminal",
            ["explorer"] = "Dosya Gezgini",
            ["discord"] = "Discord",
            ["Slack"] = "Slack",
            ["Teams"] = "Microsoft Teams",
            ["OUTLOOK"] = "Outlook",
            ["WINWORD"] = "Word",
            ["EXCEL"] = "Excel",
            ["POWERPNT"] = "PowerPoint",
            ["spotify"] = "Spotify",
            ["steam"] = "Steam",
            ["notepad"] = "Not Defteri",
            ["Idle / Boşta"] = "Boşta",
            ["Gizli uygulama"] = "Gizli uygulama",
        };

        public static string GetFriendlyName(string processName)
        {
            if (string.IsNullOrWhiteSpace(processName))
                return processName;

            foreach (var (key, label) in Known)
            {
                if (processName.Contains(key, StringComparison.OrdinalIgnoreCase))
                    return label;
            }

            if (processName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                return processName[..^4];

            return processName;
        }
    }
}
