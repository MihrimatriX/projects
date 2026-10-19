using System;
using System.Linq;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class CategoryService
    {
        private readonly DatabaseService _db;
        private readonly AutoCategorizationService _auto = new();

        public CategoryService(DatabaseService db) => _db = db;

        public void Refresh() { /* rules read from DB each call */ }

        public UsageCategory GetCategory(string processName)
        {
            var rules = _db.GetCategoryRules();
            foreach (var rule in rules.OrderByDescending(r => r.Priority))
            {
                if (processName.Contains(rule.Pattern, StringComparison.OrdinalIgnoreCase))
                    return rule.Category;
            }

            var predicted = _auto.Predict(processName, rules);
            if (predicted.HasValue)
                return predicted.Value;

            return CategoryDefaults.GetCategory(processName);
        }

        public static string GetLabel(UsageCategory category) => CategoryDefaults.GetLabel(category);
    }
}
