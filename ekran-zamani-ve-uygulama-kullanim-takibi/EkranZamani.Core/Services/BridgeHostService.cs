using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace EkranZamani.Services
{
    public class BridgeHostService : IDisposable
    {
        // Uzantı en geç ~30 sn'de bir gönderir; daha uzun süre uyku/hata demektir, kaydı şişirmesin.
        internal const int MaxSecondsPerReport = 300;

        private readonly DatabaseService _db;
        private readonly Func<EkranZamani.Models.AppSettings> _settings;
        private HttpListener? _listener;
        private CancellationTokenSource? _cts;
        private int _port;
        public bool IsRunning { get; private set; }
        public string? LastError { get; private set; }

        public BridgeHostService(DatabaseService db, Func<EkranZamani.Models.AppSettings>? settings = null)
        {
            _db = db;
            _settings = settings ?? (() => AppServices.Settings.Current);
        }

        /// <summary>
        /// Tarayıcıdaki herhangi bir web sitesi de 127.0.0.1'e istek atabilir (Origin başlığıyla).
        /// Yalnızca başlıksız (yerel araç) ya da tarayıcı eklentisi kökenli isteklere izin verilir.
        /// </summary>
        public static bool IsAllowedOrigin(string? origin) =>
            string.IsNullOrEmpty(origin) ||
            origin.StartsWith("chrome-extension://", StringComparison.OrdinalIgnoreCase) ||
            origin.StartsWith("moz-extension://", StringComparison.OrdinalIgnoreCase) ||
            origin.StartsWith("extension://", StringComparison.OrdinalIgnoreCase);

        public void Start(int port)
        {
            Stop();
            _port = port;
            _cts = new CancellationTokenSource();

            try
            {
                _listener = new HttpListener();
                _listener.Prefixes.Add($"http://127.0.0.1:{port}/");
                _listener.Start();
                IsRunning = true;
                LastError = null;
                _ = Task.Run(() => ListenLoop(_cts.Token));
            }
            catch (Exception ex)
            {
                IsRunning = false;
                LastError = ex.Message;
            }
        }

        public void Stop()
        {
            _cts?.Cancel();
            if (_listener?.IsListening == true)
                _listener.Stop();
            _listener?.Close();
            _listener = null;
            IsRunning = false;
        }

        private async Task ListenLoop(CancellationToken token)
        {
            while (!token.IsCancellationRequested && _listener != null && _listener.IsListening)
            {
                try
                {
                    var context = await _listener.GetContextAsync();
                    _ = Task.Run(() => HandleRequest(context), token);
                }
                catch (HttpListenerException) when (token.IsCancellationRequested)
                {
                    break;
                }
                catch (ObjectDisposedException)
                {
                    break;
                }
            }
        }

        private void HandleRequest(HttpListenerContext context)
        {
            try
            {
                var req = context.Request;
                var res = context.Response;
                // CORS "*" yok: eklenti host_permissions sayesinde CORS'a takılmaz; web sitelerinin okumasına gerek yok.
                if (!IsAllowedOrigin(req.Headers["Origin"]))
                {
                    res.StatusCode = 403;
                    WriteText(res, "Forbidden");
                    return;
                }

                if (req.HttpMethod == "OPTIONS")
                {
                    res.StatusCode = 204;
                    res.Close();
                    return;
                }

                string path = req.Url?.AbsolutePath?.TrimEnd('/') ?? "";
                if (req.HttpMethod == "GET" && path == "/api/health")
                {
                    WriteJson(res, new { ok = true, service = "EkranZamani", port = _port });
                    return;
                }

                if (req.HttpMethod == "POST" && path == "/api/web-usage")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    var body = reader.ReadToEnd();
                    HandleWebUsage(body);
                    WriteJson(res, new { ok = true });
                    return;
                }

                res.StatusCode = 404;
                WriteText(res, "Not found");
            }
            catch (Exception ex)
            {
                try
                {
                    context.Response.StatusCode = 500;
                    WriteText(context.Response, ex.Message);
                }
                catch { /* ignore */ }
            }
        }

        private void HandleWebUsage(string body)
        {
            var settings = _settings();
            if (!settings.EnableBrowserExtension)
                return;

            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;

            string domain = root.TryGetProperty("domain", out var d) ? d.GetString() ?? "" : "";
            string title = root.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "";
            int seconds = root.TryGetProperty("seconds", out var s) ? s.GetInt32() : 0;

            if (seconds <= 0 || string.IsNullOrWhiteSpace(domain)) return;
            seconds = Math.Min(seconds, MaxSecondsPerReport);
            if (!settings.LogWindowTitles) title = string.Empty; // başlık kaydı kapalıysa sayfa başlığı da tutulmaz

            var end = DateTime.Now;
            var start = end.AddSeconds(-seconds);
            _db.SaveWebDomainUsage(domain, title, start, end, seconds);
        }

        private static void WriteJson(HttpListenerResponse res, object payload)
        {
            var json = JsonSerializer.Serialize(payload);
            res.ContentType = "application/json";
            var buffer = Encoding.UTF8.GetBytes(json);
            res.ContentLength64 = buffer.Length;
            res.OutputStream.Write(buffer, 0, buffer.Length);
            res.Close();
        }

        private static void WriteText(HttpListenerResponse res, string text)
        {
            var buffer = Encoding.UTF8.GetBytes(text);
            res.ContentLength64 = buffer.Length;
            res.OutputStream.Write(buffer, 0, buffer.Length);
            res.Close();
        }

        public static string GetReservationHelp(int port) =>
            $"Köprü başlamadıysa yönetici PowerShell'de:\nnetsh http add urlacl url=http://127.0.0.1:{port}/ user=Everyone";

        public void Dispose() => Stop();
    }
}

