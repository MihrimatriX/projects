using System.Net;
using System.Net.Sockets;
using System.Text;
using EkranZamani.Models;
using EkranZamani.Services;
using Microsoft.Data.Sqlite;
using Xunit;

namespace EkranZamani.Tests;

/// <summary>Tarayıcı eklentisi köprüsü, ayar dosyası gizliliği ve veri klasörü.</summary>
public class PrivacyAndBridgeTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "EkranZamani_priv_" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        try { Directory.Delete(_dir, true); } catch { /* ignore */ }
    }

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        int port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private static async Task<HttpStatusCode> Post(HttpClient http, int port, string json, string? origin)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, $"http://127.0.0.1:{port}/api/web-usage")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        if (origin != null) req.Headers.Add("Origin", origin);
        using var res = await http.SendAsync(req);
        return res.StatusCode;
    }

    [Fact]
    public async Task Bridge_accepts_extension_rejects_websites_and_caps_seconds()
    {
        var db = new DatabaseService(_dir);
        var settings = new AppSettings { LogWindowTitles = false };
        using var bridge = new BridgeHostService(db, () => settings);
        int port = FreePort();
        bridge.Start(port);
        Assert.True(bridge.IsRunning, bridge.LastError);

        using var http = new HttpClient();
        Assert.Equal(HttpStatusCode.Forbidden,
            await Post(http, port, """{"domain":"evil.com","title":"x","seconds":30}""", "https://evil.com"));
        Assert.Equal(HttpStatusCode.OK,
            await Post(http, port, """{"domain":"github.com","title":"PR","seconds":30}""", "chrome-extension://abcdef"));
        Assert.Equal(HttpStatusCode.OK,
            await Post(http, port, """{"domain":"github.com","title":"PR","seconds":99999}""", null));

        var health = await http.GetAsync($"http://127.0.0.1:{port}/api/health");
        Assert.Equal(HttpStatusCode.OK, health.StatusCode);
        Assert.False(health.Headers.Contains("Access-Control-Allow-Origin"));

        using var conn = new SqliteConnection($"Data Source={Path.Combine(_dir, "usage.db")}");
        conn.Open();
        using var cmd = new SqliteCommand(
            "SELECT Domain, SUM(DurationSeconds), MAX(PageTitle) FROM WebDomainUsage GROUP BY Domain;", conn);
        using var r = cmd.ExecuteReader();
        Assert.True(r.Read());
        Assert.Equal("github.com", r.GetString(0));
        Assert.Equal(30 + BridgeHostService.MaxSecondsPerReport, r.GetInt32(1));
        Assert.Equal("", r.GetString(2)); // başlık kaydı kapalı
        Assert.False(r.Read());           // evil.com yazılmadı
    }

    [Theory]
    [InlineData(null, true)]
    [InlineData("chrome-extension://id", true)]
    [InlineData("moz-extension://id", true)]
    [InlineData("https://example.com", false)]
    [InlineData("null", false)]
    public void IsAllowedOrigin(string? origin, bool expected) =>
        Assert.Equal(expected, BridgeHostService.IsAllowedOrigin(origin));

    [Fact]
    public void Smtp_password_is_encrypted_on_disk_and_round_trips()
    {
        var svc = new SettingsService(_dir);
        var s = svc.Current;
        s.SmtpPassword = "gizli-parola-123";
        s.RetentionDays = 30;
        svc.Save(s);

        var raw = File.ReadAllText(Path.Combine(_dir, "settings.json"));
        Assert.DoesNotContain("gizli-parola-123", raw);
        Assert.Contains("dpapi:", raw);
        Assert.False(File.Exists(Path.Combine(_dir, "settings.json.tmp")));

        var reloaded = new SettingsService(_dir).Current;
        Assert.Equal("gizli-parola-123", reloaded.SmtpPassword);
        Assert.Equal(30, reloaded.RetentionDays);
    }

    [Fact]
    public void Legacy_plaintext_password_is_still_read()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(Path.Combine(_dir, "settings.json"), """{"SmtpPassword":"eski"}""");
        Assert.Equal("eski", new SettingsService(_dir).Current.SmtpPassword);
    }

    [Fact]
    public void Data_folder_env_override_is_used()
    {
        var prev = Environment.GetEnvironmentVariable("EKRANZAMANI_DATA_DIR");
        try
        {
            Environment.SetEnvironmentVariable("EKRANZAMANI_DATA_DIR", _dir);
            var db = new DatabaseService();
            Assert.Equal(_dir, db.DataFolder);
            Assert.True(File.Exists(Path.Combine(_dir, "usage.db")));
        }
        finally
        {
            Environment.SetEnvironmentVariable("EKRANZAMANI_DATA_DIR", prev);
        }
    }
}
