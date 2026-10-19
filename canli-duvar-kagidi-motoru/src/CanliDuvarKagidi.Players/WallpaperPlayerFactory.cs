using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Players;

public sealed class WallpaperPlayerFactory : IWallpaperPlayerFactory
{
    public IWallpaperPlayer Create(WallpaperType type) => type switch
    {
        WallpaperType.Video => new VideoPlayer(),
        WallpaperType.Web => new WebPlayer(),
        _ => new ImagePlayer()
    };
}
