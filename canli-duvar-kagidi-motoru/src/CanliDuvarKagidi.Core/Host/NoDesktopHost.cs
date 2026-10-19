using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Host;

/// <summary>
/// Masaustune hicbir pencere gommeyen host + oynatici. CANLI_DUVAR_UITEST=1 ile arayuz testleri
/// "uygula" akisini gercek masaustunu degistirmeden calistirir; birim testleri de kullanir.
/// </summary>
public sealed class NoDesktopHost(MonitorInfo monitor) : IWallpaperHost
{
    public IntPtr WindowHandle => IntPtr.Zero;
    public MonitorInfo Monitor { get; } = monitor;
    public bool IsAttached { get; private set; }
    public Task AttachToDesktopAsync() { IsAttached = true; return Task.CompletedTask; }
    public void Show() { }
    public void Hide() { }
    public void SetBounds(MonitorInfo monitor) { }
    public void Dispose() => IsAttached = false;
}

public sealed class NoDesktopPlayerFactory : IWallpaperPlayerFactory
{
    public List<NoDesktopPlayer> Created { get; } = [];

    public IWallpaperPlayer Create(WallpaperType type)
    {
        var player = new NoDesktopPlayer();
        Created.Add(player);
        return player;
    }
}

public sealed class NoDesktopPlayer : IWallpaperPlayer
{
    public bool IsPlaying { get; private set; }
    public bool IsDisposed { get; private set; }
    public Task AttachAsync(IntPtr hostWindow, MonitorInfo monitor, WallpaperManifest manifest, string packageRoot) => Task.CompletedTask;
    public void Play() => IsPlaying = true;
    public void Pause() => IsPlaying = false;
    public void Stop() => IsPlaying = false;
    public void Resize(MonitorInfo monitor) { }
    public void Dispose() { IsPlaying = false; IsDisposed = true; }
}
