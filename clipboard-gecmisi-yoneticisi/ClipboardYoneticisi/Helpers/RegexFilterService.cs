using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi.Helpers
{
    public static class RegexFilterService
    {
        private static List<Regex>? _compiled;

        public static bool ShouldBlock(string content)
        {
            var patterns = SettingsService.Instance.Settings.RegexFilterPatterns;
            if (patterns.Count == 0 || string.IsNullOrEmpty(content))
                return false;

            _compiled ??= Compile(patterns);

            foreach (var regex in _compiled)
            {
                if (regex.IsMatch(content))
                    return true;
            }

            return false;
        }

        public static void InvalidateCache() => _compiled = null;

        private static List<Regex> Compile(IEnumerable<string> patterns)
        {
            var list = new List<Regex>();
            foreach (var pattern in patterns)
            {
                if (string.IsNullOrWhiteSpace(pattern))
                    continue;

                try
                {
                    list.Add(new Regex(pattern, RegexOptions.IgnoreCase | RegexOptions.Compiled));
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Invalid regex '{pattern}': {ex.Message}");
                }
            }
            return list;
        }
    }
}
