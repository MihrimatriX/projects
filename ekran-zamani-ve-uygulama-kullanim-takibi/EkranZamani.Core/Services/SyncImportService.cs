using System;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace EkranZamani.Services
{
    public class SyncImportService
    {
        private readonly DatabaseService _db;

        public SyncImportService(DatabaseService db) => _db = db;

        public int ImportFromFile(string path)
        {
            if (!File.Exists(path))
                throw new FileNotFoundException("Senkron dosyası bulunamadı.", path);

            var json = File.ReadAllText(path);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            string device = root.TryGetProperty("device", out var d) ? d.GetString() ?? "remote" : "remote";
            int imported = 0;
            var now = DateTime.Now;

            if (root.TryGetProperty("apps", out var apps) && apps.ValueKind == JsonValueKind.Array)
            {
                foreach (var app in apps.EnumerateArray())
                {
                    string? name = app.TryGetProperty("ProcessName", out var pn) ? pn.GetString()
                        : app.TryGetProperty("processName", out var pn2) ? pn2.GetString() : null;
                    int seconds = app.TryGetProperty("TotalSeconds", out var ts) ? ts.GetInt32()
                        : app.TryGetProperty("totalSeconds", out var ts2) ? ts2.GetInt32() : 0;

                    if (string.IsNullOrWhiteSpace(name) || seconds <= 0) continue;

                    var label = $"[{device}] {name}";
                    _db.SaveUsageRecord(label, "sync-import", now.AddSeconds(-seconds), now, seconds);
                    imported++;
                }
            }

            if (root.TryGetProperty("webDomains", out var domains) && domains.ValueKind == JsonValueKind.Array)
            {
                foreach (var dom in domains.EnumerateArray())
                {
                    string? domain = dom.TryGetProperty("Domain", out var dn) ? dn.GetString()
                        : dom.TryGetProperty("domain", out var dn2) ? dn2.GetString() : null;
                    int seconds = dom.TryGetProperty("TotalSeconds", out var ds) ? ds.GetInt32()
                        : dom.TryGetProperty("totalSeconds", out var ds2) ? ds2.GetInt32() : 0;

                    if (string.IsNullOrWhiteSpace(domain) || seconds <= 0) continue;

                    _db.SaveWebDomainUsage(domain, $"sync:{device}", now.AddSeconds(-seconds), now, seconds);
                    imported++;
                }
            }

            return imported;
        }
    }
}
