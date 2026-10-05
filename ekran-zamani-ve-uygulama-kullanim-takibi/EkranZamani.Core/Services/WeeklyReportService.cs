using System;
using System.IO;
using System.Linq;
using System.Text;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class WeeklyReportService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public WeeklyReportService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public string GenerateHtmlReport()
        {
            var daily = _db.GetDailyUsageSummary(7);
            var apps = _db.GetAppUsageSummary(7);
            int totalSec = apps.Sum(a => a.TotalSeconds);
            var domains = _db.GetWebDomainSummary(7);

            var sb = new StringBuilder();
            sb.AppendLine("<!DOCTYPE html><html lang=\"tr\"><head><meta charset=\"utf-8\"/>");
            sb.AppendLine("<title>Ekran Zamanı — Haftalık Rapor</title>");
            sb.AppendLine("<style>body{font-family:Segoe UI,sans-serif;background:#1e1e2e;color:#f0f0f5;padding:32px;max-width:720px;margin:auto}");
            sb.AppendLine("h1{color:#f59e0b}table{width:100%;border-collapse:collapse;margin:16px 0}");
            sb.AppendLine("td,th{padding:8px;border-bottom:1px solid #4a4a6a;text-align:left}</style></head><body>");
            sb.AppendLine($"<h1>Haftalık Özet</h1><p>{DateTime.Now:dd MMMM yyyy}</p>");
            sb.AppendLine($"<p><strong>Toplam ekran süresi:</strong> {FormatDuration(totalSec)}</p>");

            sb.AppendLine("<h2>Günlük dağılım</h2><table><tr><th>Gün</th><th>Süre</th></tr>");
            foreach (var d in daily)
            {
                sb.AppendLine($"<tr><td>{d.Day}</td><td>{FormatDuration(d.TotalSeconds)}</td></tr>");
            }
            sb.AppendLine("</table>");

            sb.AppendLine("<h2>En çok kullanılan uygulamalar</h2><table><tr><th>Uygulama</th><th>Süre</th></tr>");
            foreach (var a in apps.Take(10))
            {
                sb.AppendLine($"<tr><td>{System.Net.WebUtility.HtmlEncode(a.ProcessName)}</td><td>{FormatDuration(a.TotalSeconds)}</td></tr>");
            }
            sb.AppendLine("</table>");

            if (domains.Count > 0)
            {
                sb.AppendLine("<h2>Web siteleri</h2><table><tr><th>Domain</th><th>Süre</th></tr>");
                foreach (var w in domains.Take(10))
                {
                    sb.AppendLine($"<tr><td>{System.Net.WebUtility.HtmlEncode(w.Domain)}</td><td>{FormatDuration(w.TotalSeconds)}</td></tr>");
                }
                sb.AppendLine("</table>");
            }

            sb.AppendLine("<p style=\"color:#a0a0b8;font-size:12px\">Ekran Zamanı — yerel rapor</p></body></html>");
            return sb.ToString();
        }

        public string SaveAndOpenReport()
        {
            var html = GenerateHtmlReport();
            var folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads");
            Directory.CreateDirectory(folder);
            var path = Path.Combine(folder, $"ekran-zamani-haftalik-{DateTime.Now:yyyyMMdd}.html");
            File.WriteAllText(path, html, Encoding.UTF8);

            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = path,
                    UseShellExecute = true
                });
            }
            catch { /* ignore */ }

            return path;
        }

        public void TryAutoGenerate(AppSettings settings)
        {
            if (!settings.EnableWeeklyReport) return;

            var today = DateTime.Now;
            if ((int)today.DayOfWeek != settings.WeeklyReportDayOfWeek) return;
            if (settings.LastWeeklyReportDate == today.ToString("yyyy-MM-dd")) return;

            SaveAndOpenReport();
            settings.LastWeeklyReportDate = today.ToString("yyyy-MM-dd");
        }

        private static string FormatDuration(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            return $"{(int)t.TotalHours} sa {t.Minutes} dk";
        }
    }
}
