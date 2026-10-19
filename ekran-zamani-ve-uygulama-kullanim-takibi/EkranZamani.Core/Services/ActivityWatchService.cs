using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class ActivityWatchService
    {
        private readonly DatabaseService _db;
        public ActivityWatchService(DatabaseService db, CategoryService categories)
        {
            _db = db;
        }

        public string ExportToJson(int filterDays)
        {
            var records = _db.GetUsageRecords(filterDays, ascending: true);
            var events = records.Select(r =>
            {
                var start = DateTime.Parse(r.StartTime);
                return new
                {
                    timestamp = start.ToString("o"),
                    duration = (double)r.DurationSeconds,
                    data = new
                    {
                        app = r.ProcessName,
                        title = r.WindowTitle,
                        url = r.WindowTitle.StartsWith("http", StringComparison.OrdinalIgnoreCase) ? r.WindowTitle : ""
                    }
                };
            }).ToList();

            var payload = new
            {
                hostname = Environment.MachineName,
                exportedAt = DateTime.Now.ToString("o"),
                events
            };

            return JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
        }

        public int ImportFromJson(string json)
        {
            var events = ParseEvents(json);
            _db.ImportActivityWatchEvents(events);
            return events.Count;
        }

        public int ImportFromFile(string path)
        {
            var json = File.ReadAllText(path);
            return ImportFromJson(json);
        }

        public string SaveExportToDownloads(int filterDays)
        {
            var json = ExportToJson(filterDays);
            var folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads");
            Directory.CreateDirectory(folder);
            var path = Path.Combine(folder, $"activitywatch-export-{DateTime.Now:yyyyMMdd-HHmmss}.json");
            File.WriteAllText(path, json);
            return path;
        }

        public static List<ActivityWatchEvent> ParseEvents(string json)
        {
            var list = new List<ActivityWatchEvent>();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            JsonElement eventsElement;
            if (root.ValueKind == JsonValueKind.Array)
                eventsElement = root;
            else if (root.TryGetProperty("events", out var ev))
                eventsElement = ev;
            else
                return list;

            foreach (var item in eventsElement.EnumerateArray())
            {
                if (!item.TryGetProperty("timestamp", out var tsEl))
                    continue;

                double duration = item.TryGetProperty("duration", out var durEl) ? durEl.GetDouble() : 0;
                if (duration <= 0) continue;

                string? app = null, title = null, url = null;
                if (item.TryGetProperty("data", out var data))
                {
                    if (data.TryGetProperty("app", out var appEl)) app = appEl.GetString();
                    if (data.TryGetProperty("title", out var titleEl)) title = titleEl.GetString();
                    if (data.TryGetProperty("url", out var urlEl)) url = urlEl.GetString();
                }

                if (DateTime.TryParse(tsEl.GetString(), out var timestamp))
                {
                    list.Add(new ActivityWatchEvent
                    {
                        Timestamp = timestamp,
                        Duration = duration,
                        App = app,
                        Title = title,
                        Url = url
                    });
                }
            }

            return list;
        }
    }
}
