using CanliDuvarKagidi.Core.Services;

namespace CanliDuvarKagidi.Core.Models;

public sealed class UserSettings
{
    public string CatalogUrl { get; set; } = CatalogUrlResolver.BundledToken;
    public bool RunAtStartup { get; set; }
    public bool PauseOnFullscreen { get; set; } = true;
    public Dictionary<string, string> MonitorWallpapers { get; set; } = new();
}
