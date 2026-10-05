using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Abstractions;

public interface IWallpaperPlayerFactory
{
    IWallpaperPlayer Create(WallpaperType type);
}
