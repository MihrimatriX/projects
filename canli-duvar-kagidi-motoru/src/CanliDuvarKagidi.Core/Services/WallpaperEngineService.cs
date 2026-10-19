using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Host;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Core.Services;

public sealed class WallpaperEngineService : IDisposable
{
    private readonly IWallpaperPlayerFactory _playerFactory;
    private readonly InstalledWallpaperService _installed;
    private readonly SettingsService _settings;
    private readonly FullscreenDetectionService _fullscreen;
    private readonly Func<MonitorInfo, IWallpaperHost> _hostFactory;
    private readonly Dictionary<string, MonitorSession> _sessions = new();
    private readonly System.Threading.Timer _pauseTimer;
    private bool _pausedByFullscreen;
    private bool _userPaused;
    private bool _disposed;

    public WallpaperEngineService(
        IWallpaperPlayerFactory playerFactory,
        InstalledWallpaperService installed,
        SettingsService settings,
        FullscreenDetectionService fullscreen,
        Func<MonitorInfo, IWallpaperHost>? hostFactory = null)
    {
        // Arayuz testleri gercek masaustune dokunmayan bir host verir
        _hostFactory = hostFactory ?? (m => new DesktopWallpaperHost(m));
        _playerFactory = playerFactory;
        _installed = installed;
        _settings = settings;
        _fullscreen = fullscreen;
        // _sessions ve ayar dosyasi UI thread'inden yonetilir; zamanlayici kontrolu oraya post edilir.
        var ui = SynchronizationContext.Current;
        _pauseTimer = new System.Threading.Timer(
            s => { if (ui != null) ui.Post(CheckFullscreenPause, s); else CheckFullscreenPause(s); },
            null, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(1));
    }

    public bool HasActiveWallpapers => _sessions.Count > 0;

    public event EventHandler? SessionsChanged;

    /// <summary>Kullanicinin elle duraklatmasi (tepsi / Monitorler). Kaydedilmez; yeni uygulanan da duraklatilmis baslar.</summary>
    public bool IsUserPaused
    {
        get => _userPaused;
        set
        {
            if (_userPaused == value)
                return;
            _userPaused = value;
            SyncPlayback();
            SessionsChanged?.Invoke(this, EventArgs.Empty);
        }
    }

    private bool ShouldPause => _userPaused || _pausedByFullscreen;

    private void SyncPlayback()
    {
        foreach (var session in _sessions.Values)
        {
            if (ShouldPause) session.Player.Pause();
            else session.Player.Play();
        }
    }

    public async Task ApplyWallpaperAsync(string monitorId, string wallpaperId)
    {
        var monitor = MonitorService.FindById(monitorId)
            ?? throw new InvalidOperationException($"Monitor bulunamadi: {monitorId}");

        var manifest = _installed.LoadManifest(wallpaperId)
            ?? throw new InvalidOperationException($"Duvar kagidi kurulu degil: {wallpaperId}");

        await RemoveWallpaperAsync(monitorId);

        var host = _hostFactory(monitor);
        var player = _playerFactory.Create(manifest.WallpaperType);
        try
        {
            await host.AttachToDesktopAsync();
            var packageRoot = _installed.GetPackagePath(wallpaperId);
            await player.AttachAsync(host.WindowHandle, monitor, manifest, packageRoot);
            if (ShouldPause) player.Pause();
            else player.Play();
        }
        catch
        {
            // Basarisiz denemede bos host penceresi masaustunde kalmasin
            player.Dispose();
            host.Dispose();
            throw;
        }

        _sessions[monitorId] = new MonitorSession(monitorId, wallpaperId, host, player);

        var settings = _settings.Load();
        settings.MonitorWallpapers[monitorId] = wallpaperId;
        _settings.Save(settings);
        SessionsChanged?.Invoke(this, EventArgs.Empty);
    }

    public Task RemoveWallpaperAsync(string monitorId)
    {
        if (_sessions.TryGetValue(monitorId, out var session))
        {
            session.Dispose();
            _sessions.Remove(monitorId);

            var settings = _settings.Load();
            settings.MonitorWallpapers.Remove(monitorId);
            _settings.Save(settings);
            SessionsChanged?.Invoke(this, EventArgs.Empty);
        }

        return Task.CompletedTask;
    }

    public async Task RestoreSavedWallpapersAsync()
    {
        var settings = _settings.Load();
        foreach (var (monitorId, wallpaperId) in settings.MonitorWallpapers.ToList())
        {
            if (!_installed.IsInstalled(wallpaperId))
                continue;

            try
            {
                await ApplyWallpaperAsync(monitorId, wallpaperId);
            }
            catch
            {
                // skip broken restore entries
            }
        }
    }

    public bool IsDesktopAttached()
    {
        foreach (var session in _sessions.Values)
        {
            if (!session.Host.IsAttached || !Native.NativeMethods.IsWindow(session.Host.WindowHandle))
                return false;
        }

        return _sessions.Count > 0;
    }

    public async Task ReconnectAllAsync()
    {
        var active = _sessions.ToDictionary(kvp => kvp.Key, kvp => kvp.Value.WallpaperId);
        await ClearAllAsync();

        foreach (var (monitorId, wallpaperId) in active)
        {
            try
            {
                await ApplyWallpaperAsync(monitorId, wallpaperId);
            }
            catch
            {
                // continue reconnecting others
            }
        }
    }

    public IReadOnlyDictionary<string, string> GetActiveAssignments() =>
        _sessions.ToDictionary(kvp => kvp.Key, kvp => kvp.Value.WallpaperId);

    private async Task ClearAllAsync()
    {
        foreach (var monitorId in _sessions.Keys.ToList())
            await RemoveWallpaperAsync(monitorId);
    }

    private void CheckFullscreenPause(object? state)
    {
        if (_disposed)
            return;

        UserSettings settings;
        try { settings = _settings.Load(); }
        catch { return; } // bozuk/kilitli ayar dosyasi zamanlayicida sureci cokertmesin

        // Ayar kapatilirsa duraklatilmis oynaticilar da devam etsin
        var fullscreen = settings.PauseOnFullscreen && _fullscreen.IsForegroundFullscreen();
        if (fullscreen != _pausedByFullscreen)
        {
            _pausedByFullscreen = fullscreen;
            SyncPlayback();
        }
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _pauseTimer.Dispose();
        foreach (var session in _sessions.Values)
            session.Dispose();
        _sessions.Clear();
        _disposed = true;
    }

    private sealed class MonitorSession : IDisposable
    {
        public MonitorSession(string monitorId, string wallpaperId, IWallpaperHost host, IWallpaperPlayer player)
        {
            MonitorId = monitorId;
            WallpaperId = wallpaperId;
            Host = host;
            Player = player;
        }

        public string MonitorId { get; }
        public string WallpaperId { get; }
        public IWallpaperHost Host { get; }
        public IWallpaperPlayer Player { get; }

        public void Dispose()
        {
            Player.Dispose();
            Host.Dispose();
        }
    }
}
