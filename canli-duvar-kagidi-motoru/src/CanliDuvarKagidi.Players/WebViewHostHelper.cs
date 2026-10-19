using System.Drawing;
using Microsoft.Web.WebView2.Core;

namespace CanliDuvarKagidi.Players;

internal sealed class WebViewHost : IDisposable
{
    private CoreWebView2Controller? _controller;
    private bool _disposed;

    public CoreWebView2? Core { get; private set; }

    public Task AttachAsync(IntPtr hostWindow, int width, int height) =>
        PlayerUiThread.InvokeAsync(async () =>
        {
            var userData = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CanliDuvarKagidi",
                "WebView2"); // ortak profil: her uygulamada yeni klasor birikmesin
            Directory.CreateDirectory(userData);

            var env = await CoreWebView2Environment.CreateAsync(null, userData);
            _controller = await env.CreateCoreWebView2ControllerAsync(hostWindow);
            _controller.Bounds = new Rectangle(0, 0, width, height);
            Core = _controller.CoreWebView2;
            Core.Settings.IsStatusBarEnabled = false;
            Core.Settings.AreDefaultContextMenusEnabled = false;
        });

    // CoreWebView2 yalnizca olusturuldugu oynatici thread'inden cagrilabilir;
    // UI/zamanlayici thread'lerinden gelen cagrilar oraya kuyruklanir (bloklamadan).
    public void Navigate(string uri) =>
        _ = PlayerUiThread.InvokeAsync(() => Core?.Navigate(uri));

    public void ExecuteScript(string script) =>
        _ = PlayerUiThread.InvokeAsync(() => { _ = Core?.ExecuteScriptAsync(script); });

    public void Resize(int width, int height) =>
        PlayerUiThread.Invoke(() =>
        {
            if (_controller != null)
                _controller.Bounds = new Rectangle(0, 0, width, height);
        });

    public void Dispose()
    {
        if (_disposed)
            return;

        PlayerUiThread.Invoke(() =>
        {
            _controller?.Close();
            _controller = null;
            Core = null;
        });
        _disposed = true;
    }
}
