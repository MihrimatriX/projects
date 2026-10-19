using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Players;

public sealed class VideoPlayer : IWallpaperPlayer
{
    private WebViewHost? _host;
    private bool _disposed;

    public async Task AttachAsync(IntPtr hostWindow, MonitorInfo monitor, WallpaperManifest manifest, string packageRoot)
    {
        var videoPath = manifest.ResolveEntryPath(packageRoot);
        if (!File.Exists(videoPath))
            throw new FileNotFoundException("Video dosyasi bulunamadi.", videoPath);

        var html = BuildVideoHtml(videoPath);
        var tempHtml = Path.Combine(Path.GetTempPath(), $"cdk-video-{Guid.NewGuid():N}.html");
        await File.WriteAllTextAsync(tempHtml, html);

        _host = new WebViewHost();
        await _host.AttachAsync(hostWindow, monitor.Width, monitor.Height);
        _host.Navigate(new Uri(tempHtml).AbsoluteUri);
    }

    public void Play() =>
        _host?.ExecuteScript("var v=document.querySelector('video'); if(v){ v.play(); }");

    public void Pause() =>
        _host?.ExecuteScript("var v=document.querySelector('video'); if(v){ v.pause(); }");

    public void Stop() =>
        _host?.ExecuteScript("var v=document.querySelector('video'); if(v){ v.pause(); v.currentTime=0; }");

    public void Resize(MonitorInfo monitor) => _host?.Resize(monitor.Width, monitor.Height);

    public void Dispose()
    {
        if (_disposed)
            return;

        _host?.Dispose();
        _disposed = true;
    }

    private static string BuildVideoHtml(string videoPath)
    {
        var uri = new Uri(videoPath).AbsoluteUri;
        return $$"""
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<style>
html, body { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background:#000; }
video { width:100%; height:100%; object-fit:cover; }
</style>
</head>
<body>
<video autoplay loop muted playsinline src="{{uri}}"></video>
</body>
</html>
""";
    }
}
