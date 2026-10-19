using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class SyncExportService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;
        private readonly ExportService _export;

        public SyncExportService(DatabaseService db, CategoryService categories, ExportService export)
        {
            _db = db;
            _categories = categories;
            _export = export;
        }

        public string? ExportSnapshot(AppSettings settings, bool useDefaultFolderIfMissing = false)
        {
            string? folder = settings.SyncExportFolder?.Trim();
            if (string.IsNullOrWhiteSpace(folder))
            {
                if (!useDefaultFolderIfMissing)
                    return null;
                folder = Path.Combine(_db.DataFolder, "sync");
            }

            if (!settings.EnableSyncExport && !useDefaultFolderIfMissing)
                return null;
            Directory.CreateDirectory(folder);

            var apps = _db.GetAppUsageSummary(7).Select(a => new
            {
                a.ProcessName,
                a.TotalSeconds,
                Category = CategoryService.GetLabel(_categories.GetCategory(a.ProcessName))
            }).ToList();

            var payload = new
            {
                exportedAt = DateTime.UtcNow,
                device = Environment.MachineName,
                periodDays = 7,
                apps,
                webDomains = _db.GetWebDomainSummary(7),
                dailyTotals = _db.GetDailyUsageSummary(7)
            };

            var path = Path.Combine(folder, "ekran-zamani-sync.json");
            var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(path, json);
            return path;
        }

        public void TryExportIfDue(AppSettings settings)
        {
            if (!settings.EnableSyncExport) return;

            int interval = Math.Max(15, settings.SyncExportIntervalMinutes);
            if (DateTime.TryParse(settings.LastSyncExportUtc, out var last))
            {
                if ((DateTime.UtcNow - last).TotalMinutes < interval)
                    return;
            }

            ExportSnapshot(settings);
            settings.LastSyncExportUtc = DateTime.UtcNow.ToString("o");
        }
    }
}
