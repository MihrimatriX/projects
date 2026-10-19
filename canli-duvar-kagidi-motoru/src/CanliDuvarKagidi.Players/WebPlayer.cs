using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Players;

public sealed class WebPlayer : IWallpaperPlayer
{
    private WebViewHost? _host;
    private bool _disposed;

    public async Task AttachAsync(IntPtr hostWindow, MonitorInfo monitor, WallpaperManifest manifest, string packageRoot)
    {
        var sourcePath = manifest.ResolveEntryPath(packageRoot);
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("Web giris dosyasi bulunamadi.", sourcePath);

        _host = new WebViewHost();
        await _host.AttachAsync(hostWindow, monitor.Width, monitor.Height);
        _host.Navigate(new Uri(sourcePath).AbsoluteUri);
    }

    public void Play() =>
        _host?.ExecuteScript("document.dispatchEvent(new Event('resume'));");

    public void Pause() =>
        _host?.ExecuteScript("document.dispatchEvent(new Event('pause'));");

    public void Stop() => _host?.Navigate("about:blank");

    public void Resize(MonitorInfo monitor) => _host?.Resize(monitor.Width, monitor.Height);

    public void Dispose()
    {
        if (_disposed)
            return;

        _host?.Dispose();
        _disposed = true;
    }
}
