using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Abstractions;

public interface IWallpaperPlayer : IDisposable
{
    Task AttachAsync(IntPtr hostWindow, MonitorInfo monitor, WallpaperManifest manifest, string packageRoot);
    void Play();
    void Pause();
    void Stop();
    void Resize(MonitorInfo monitor);
}
