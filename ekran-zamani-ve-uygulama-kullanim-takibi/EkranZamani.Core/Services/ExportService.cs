using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class ExportService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public ExportService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public string ExportJson(int filterDays)
        {
            var records = _db.GetUsageRecords(filterDays);
            var apps = records.ConvertAll(r => new
            {
                r.ProcessName,
                r.WindowTitle,
                r.StartTime,
                r.EndTime,
                r.DurationSeconds,
                Category = CategoryService.GetLabel(_categories.GetCategory(r.ProcessName))
            });

            var web = _db.GetWebDomainSummary(filterDays).ConvertAll(w => new
            {
                w.Domain,
                w.TotalSeconds
            });

            var payload = new { apps, webDomains = web };
            return JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
        }

        public string ExportCsv(int filterDays)
        {
            var records = _db.GetUsageRecords(filterDays);
            var sb = new StringBuilder();
            sb.AppendLine("Type,ProcessName,WindowTitle,StartTime,EndTime,DurationSeconds,Category");

            foreach (var r in records)
            {
                var category = CategoryService.GetLabel(_categories.GetCategory(r.ProcessName));
                sb.AppendLine(string.Join(",",
                    "app",
                    CsvEscape(r.ProcessName),
                    CsvEscape(r.WindowTitle),
                    CsvEscape(r.StartTime),
                    CsvEscape(r.EndTime),
                    r.DurationSeconds.ToString(),
                    CsvEscape(category)));
            }

            foreach (var w in _db.GetWebDomainSummary(filterDays))
            {
                sb.AppendLine(string.Join(",",
                    "web",
                    CsvEscape(w.Domain),
                    "",
                    "",
                    "",
                    w.TotalSeconds.ToString(),
                    ""));
            }

            return sb.ToString();
        }

        public string SaveToDownloads(string content, string extension)
        {
            var folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads");
            Directory.CreateDirectory(folder);

            var fileName = $"ekran-zamani-{DateTime.Now:yyyyMMdd-HHmmss}.{extension}";
            var path = Path.Combine(folder, fileName);
            File.WriteAllText(path, content, Encoding.UTF8);
            return path;
        }

        private static string CsvEscape(string value)
        {
            if (value.Contains('"') || value.Contains(',') || value.Contains('\n'))
                return $"\"{value.Replace("\"", "\"\"")}\"";
            return value;
        }
    }
}
