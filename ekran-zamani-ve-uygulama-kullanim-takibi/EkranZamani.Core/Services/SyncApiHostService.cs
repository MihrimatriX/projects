using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    /// <summary>
    /// Yerel ağ self-host: GET snapshot, POST içe aktarma.
    /// </summary>
    public class SyncApiHostService : IDisposable
    {
        private readonly SyncExportService _export;
        private readonly SyncImportService _import;
        private readonly Func<AppSettings> _getSettings;

        private HttpListener? _listener;
        private CancellationTokenSource? _cts;
        public bool IsRunning { get; private set; }
        public string? LastError { get; private set; }

        public SyncApiHostService(SyncExportService export, SyncImportService import, Func<AppSettings> getSettings)
        {
            _export = export;
            _import = import;
            _getSettings = getSettings;
        }

        public void Start(int port)
        {
            Stop();
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
                    var ctx = await _listener.GetContextAsync();
                    _ = Task.Run(() => Handle(ctx), token);
                }
                catch when (token.IsCancellationRequested) { break; }
                catch (ObjectDisposedException) { break; }
            }
        }

        private void Handle(HttpListenerContext context)
        {
            try
            {
                var req = context.Request;
                var res = context.Response;
                // CORS başlığı bilerek yok: "*" olsaydı ziyaret edilen herhangi bir web sitesi kullanım verisini okuyabilirdi.

                if (!BridgeHostService.IsAllowedOrigin(req.Headers["Origin"]))
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

                if (req.HttpMethod == "GET" && path == "/api/sync")
                {
                    var settings = _getSettings();
                    var exportPath = _export.ExportSnapshot(settings, useDefaultFolderIfMissing: true);
                    string json = exportPath != null && File.Exists(exportPath)
                        ? File.ReadAllText(exportPath)
                        : JsonSerializer.Serialize(new { ok = false, message = "Export başarısız" });
                    WriteRawJson(res, json);
                    return;
                }

                if (req.HttpMethod == "POST" && path == "/api/sync/import")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    var body = reader.ReadToEnd();
                    var temp = Path.Combine(Path.GetTempPath(), $"ez-sync-{Guid.NewGuid():N}.json");
                    File.WriteAllText(temp, body);
                    int count = _import.ImportFromFile(temp);
                    try { File.Delete(temp); } catch { }
                    WriteJson(res, new { ok = true, imported = count });
                    return;
                }

                if (req.HttpMethod == "GET" && path == "/api/health")
                {
                    WriteJson(res, new { ok = true, service = "EkranZamani-Sync" });
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
                catch { }
            }
        }

        private static void WriteJson(HttpListenerResponse res, object payload)
        {
            var json = JsonSerializer.Serialize(payload);
            WriteRawJson(res, json);
        }

        private static void WriteRawJson(HttpListenerResponse res, string json)
        {
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

        public void Dispose() => Stop();
    }
}
