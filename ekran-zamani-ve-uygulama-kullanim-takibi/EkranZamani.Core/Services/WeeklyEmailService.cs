using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Text;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class WeeklyEmailService
    {
        private readonly DatabaseService _db;
        private readonly CategoryService _categories;

        public WeeklyEmailService(DatabaseService db, CategoryService categories)
        {
            _db = db;
            _categories = categories;
        }

        public bool IsConfigured(AppSettings settings) =>
            settings.EnableWeeklyEmail
            && !string.IsNullOrWhiteSpace(settings.SmtpHost)
            && !string.IsNullOrWhiteSpace(settings.EmailTo)
            && !string.IsNullOrWhiteSpace(settings.EmailFrom);

        public string BuildPlainSummary()
        {
            var apps = _db.GetAppUsageSummary(7);
            int total = apps.Sum(a => a.TotalSeconds);
            var sb = new StringBuilder();
            sb.AppendLine($"Ekran Zamanı — haftalık özet ({DateTime.Now:dd.MM.yyyy})");
            sb.AppendLine($"Toplam: {FormatDuration(total)}");
            sb.AppendLine();
            sb.AppendLine("En çok kullanılan:");
            foreach (var a in apps.Take(8))
                sb.AppendLine($"  • {a.ProcessName}: {FormatDuration(a.TotalSeconds)}");
            return sb.ToString();
        }

        public void TrySendWeekly(AppSettings settings, string htmlReport)
        {
            if (!IsConfigured(settings)) return;

            using var client = new SmtpClient(settings.SmtpHost!, settings.SmtpPort)
            {
                EnableSsl = settings.SmtpUseSsl,
                DeliveryMethod = SmtpDeliveryMethod.Network
            };

            if (!string.IsNullOrWhiteSpace(settings.SmtpUser))
                client.Credentials = new NetworkCredential(settings.SmtpUser, settings.SmtpPassword ?? "");

            using var message = new MailMessage(settings.EmailFrom!, settings.EmailTo!)
            {
                Subject = $"Ekran Zamanı — haftalık rapor {DateTime.Now:dd.MM.yyyy}",
                Body = BuildPlainSummary(),
                IsBodyHtml = false
            };

            var htmlBytes = Encoding.UTF8.GetBytes(htmlReport);
            message.Attachments.Add(new Attachment(new MemoryStream(htmlBytes), "haftalik-rapor.html", "text/html"));
            client.Send(message);
        }

        public void TryAutoSend(AppSettings settings, string htmlReport)
        {
            if (!IsConfigured(settings)) return;

            var today = DateTime.Now;
            if ((int)today.DayOfWeek != settings.WeeklyReportDayOfWeek) return;
            if (settings.LastWeeklyEmailDate == today.ToString("yyyy-MM-dd")) return;

            TrySendWeekly(settings, htmlReport);
            settings.LastWeeklyEmailDate = today.ToString("yyyy-MM-dd");
        }

        private static string FormatDuration(int seconds)
        {
            var t = TimeSpan.FromSeconds(seconds);
            return $"{(int)t.TotalHours} sa {t.Minutes} dk";
        }
    }
}
