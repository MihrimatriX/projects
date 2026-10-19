using System.Drawing;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public static class MonitorService
{
    public static IReadOnlyList<MonitorInfo> GetMonitors()
    {
        var screens = Screen.AllScreens;
        return screens.Select((screen, index) => new MonitorInfo
        {
            Id = screen.DeviceName.TrimEnd('\0'),
            Name = $"Monitör {index + 1}{(screen.Primary ? " (birincil)" : "")}",
            X = screen.Bounds.X,
            Y = screen.Bounds.Y,
            Width = screen.Bounds.Width,
            Height = screen.Bounds.Height,
            IsPrimary = screen.Primary
        }).ToList();
    }

    public static MonitorInfo? FindById(string monitorId) =>
        GetMonitors().FirstOrDefault(m => m.Id == monitorId);
}
