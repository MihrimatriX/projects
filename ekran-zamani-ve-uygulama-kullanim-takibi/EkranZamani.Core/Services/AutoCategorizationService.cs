using System;
using System.Collections.Generic;
using System.Linq;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    /// <summary>
    /// Kural tabanlı "ML-lite": kullanıcı kuralları ve process adı benzerliği ile tahmin.
    /// </summary>
    public class AutoCategorizationService
    {
        public UsageCategory? Predict(string processName, IReadOnlyList<CategoryRule> rules)
        {
            if (string.IsNullOrWhiteSpace(processName) || rules.Count == 0)
                return null;

            var normalized = Normalize(processName);
            int bestScore = 0;
            UsageCategory? best = null;

            foreach (var rule in rules.OrderByDescending(r => r.Priority))
            {
                var pattern = Normalize(rule.Pattern);
                if (string.IsNullOrEmpty(pattern)) continue;

                int score = ScoreMatch(normalized, pattern);
                if (score > bestScore)
                {
                    bestScore = score;
                    best = rule.Category;
                }
            }

            return bestScore >= 60 ? best : null;
        }

        private static int ScoreMatch(string process, string pattern)
        {
            if (process.Contains(pattern, StringComparison.OrdinalIgnoreCase)
                || pattern.Contains(process, StringComparison.OrdinalIgnoreCase))
                return 100;

            var processTokens = Tokenize(process);
            var patternTokens = Tokenize(pattern);
            if (processTokens.Count == 0 || patternTokens.Count == 0)
                return 0;

            int hits = processTokens.Count(t => patternTokens.Contains(t));
            int max = Math.Max(processTokens.Count, patternTokens.Count);
            return (int)(100.0 * hits / max);
        }

        private static List<string> Tokenize(string value)
        {
            var parts = value.Split(new[] { ' ', '.', '-', '_' }, StringSplitOptions.RemoveEmptyEntries);
            return parts.Select(p => p.ToLowerInvariant()).Where(p => p.Length >= 2).Distinct().ToList();
        }

        private static string Normalize(string name)
        {
            var n = name.Trim().ToLowerInvariant();
            if (n.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                n = n[..^4];
            return n;
        }
    }
}
