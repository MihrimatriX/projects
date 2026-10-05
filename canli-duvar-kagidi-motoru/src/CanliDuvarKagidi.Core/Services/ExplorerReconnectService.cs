using CanliDuvarKagidi.Core.Host;

namespace CanliDuvarKagidi.Core.Services;

public sealed class ExplorerReconnectService : IDisposable
{
    private readonly WallpaperEngineService _engine;
    private readonly System.Threading.Timer _timer;
    private bool _reconnecting;

    public ExplorerReconnectService(WallpaperEngineService engine)
    {
        _engine = engine;
        // Explorer yeniden baslarsa WorkerW ile birlikte host pencerelerimiz de yok olur; 3 sn'de bir
        // kontrol edip yeniden baglaniriz. Host pencereleri mesaj pompasi olan UI thread'inde
        // olusturulmali, bu yuzden kontrol (varsa) UI SynchronizationContext'ine post edilir.
        var ui = SynchronizationContext.Current;
        _timer = new System.Threading.Timer(
            s => { if (ui != null) ui.Post(CheckExplorerAsync, s); else CheckExplorerAsync(s); },
            null, TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(3));
    }

    private async void CheckExplorerAsync(object? state)
    {
        if (_reconnecting || !_engine.HasActiveWallpapers)
            return;

        try
        {
            _reconnecting = true;
            if (!_engine.IsDesktopAttached())
            {
                DesktopWorkerW.ResetCache();
                await _engine.ReconnectAllAsync();
            }
        }
        catch
        {
            // retry on next tick
        }
        finally
        {
            _reconnecting = false;
        }
    }

    public void Dispose() => _timer.Dispose();
}
