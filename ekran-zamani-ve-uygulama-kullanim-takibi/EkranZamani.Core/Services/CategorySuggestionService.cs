using System;
using System.Collections.Generic;
using System.Linq;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class CategorySuggestion
    {
        public required string Pattern { get; init; }
        public UsageCategory SuggestedCategory { get; init; }
        public int TotalSeconds { get; init; }
        public string Reason { get; init; } = string.Empty;
    }

    public class CategorySuggestionService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        private const int MinSeconds = 900;

        public CategorySuggestionService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public List<CategorySuggestion> GetSuggestions(int filterDays = 7, int maxItems = 8)
        {
            var existingPatterns = _db.GetCategoryRules()
                .Select(r => r.Pattern)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            var suggestions = new List<CategorySuggestion>();

            foreach (var app in _db.GetAppUsageSummary(filterDays))
            {
                if (app.TotalSeconds < MinSeconds) continue;

                bool hasRule = existingPatterns.Any(p =>
                    app.ProcessName.Contains(p, StringComparison.OrdinalIgnoreCase));
                if (hasRule) continue;

                var suggested = CategoryDefaults.GetCategory(app.ProcessName);
                if (suggested == UsageCategory.Neutral) continue;

                suggestions.Add(new CategorySuggestion
                {
                    Pattern = app.ProcessName.ToLowerInvariant(),
                    SuggestedCategory = suggested,
                    TotalSeconds = app.TotalSeconds,
                    Reason = $"Son {filterDays} günde {FormatDuration(app.TotalSeconds)}, kural yok"
                });
            }

            return suggestions
                .OrderByDescending(s => s.TotalSeconds)
                .Take(maxItems)
                .ToList();
        }

        public void ApplySuggestion(CategorySuggestion suggestion)
        {
            _db.AddCategoryRule(suggestion.Pattern, suggestion.SuggestedCategory, 55);
        }

        private static string FormatDuration(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            if (t.TotalHours >= 1)
                return $"{(int)t.TotalHours} sa {t.Minutes} dk";
            return $"{t.Minutes} dk";
        }
    }
}
