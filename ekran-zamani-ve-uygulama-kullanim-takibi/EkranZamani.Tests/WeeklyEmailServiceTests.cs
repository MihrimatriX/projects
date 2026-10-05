using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class WeeklyEmailServiceTests
{
    [Fact]
    public void IsConfigured_requires_host_and_addresses()
    {
        var db = new DatabaseService(Path.Combine(Path.GetTempPath(), "EkranZamani_mail_" + Guid.NewGuid().ToString("N")));
        var service = new WeeklyEmailService(db, new CategoryService(db));

        Assert.False(service.IsConfigured(new AppSettings { EnableWeeklyEmail = true }));
        Assert.True(service.IsConfigured(new AppSettings
        {
            EnableWeeklyEmail = true,
            SmtpHost = "smtp.example.com",
            EmailFrom = "a@b.com",
            EmailTo = "c@d.com"
        }));
    }

    [Fact]
    public void BuildPlainSummary_includes_totals()
    {
        var folder = Path.Combine(Path.GetTempPath(), "EkranZamani_mail2_" + Guid.NewGuid().ToString("N"));
        var db = new DatabaseService(folder);
        var day = DateTime.Now.Date;
        db.SaveUsageRecord("code", "x", day, day.AddHours(1), 3600);

        var text = new WeeklyEmailService(db, new CategoryService(db)).BuildPlainSummary();
        Assert.Contains("haftalık özet", text, StringComparison.OrdinalIgnoreCase);

        try { Directory.Delete(folder, true); } catch { }
    }
}
