using CanliDuvarKagidi.Core.Native;

namespace CanliDuvarKagidi.Core.Services;

public sealed class FullscreenDetectionService
{
    public bool IsForegroundFullscreen()
    {
        var foreground = NativeMethods.GetForegroundWindow();
        if (foreground == IntPtr.Zero)
            return false;

        if (!NativeMethods.GetWindowRect(foreground, out var rect))
            return false;

        if (!NativeMethods.IsZoomed(foreground))
            return false;

        var monitors = MonitorService.GetMonitors();
        foreach (var monitor in monitors)
        {
            if (rect.Left <= monitor.X &&
                rect.Top <= monitor.Y &&
                rect.Width >= monitor.Width - 4 &&
                rect.Height >= monitor.Height - 4)
            {
                return true;
            }
        }

        return false;
    }
}
