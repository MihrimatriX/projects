using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Abstractions;

public interface IWallpaperHost : IDisposable
{
    IntPtr WindowHandle { get; }
    MonitorInfo Monitor { get; }
    bool IsAttached { get; }
    Task AttachToDesktopAsync();
    void Show();
    void Hide();
    void SetBounds(MonitorInfo monitor);
}
