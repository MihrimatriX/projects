using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;

namespace CanliDuvarKagidi.Players;

public sealed class ImagePlayer : IWallpaperPlayer
{
    private Form? _form;
    private PictureBox? _pictureBox;
    private bool _disposed;

    public Task AttachAsync(IntPtr hostWindow, MonitorInfo monitor, WallpaperManifest manifest, string packageRoot)
    {
        var imagePath = manifest.ResolveEntryPath(packageRoot);
        if (!File.Exists(imagePath))
            throw new FileNotFoundException("Gorsel dosyasi bulunamadi.", imagePath);

        return PlayerUiThread.InvokeAsync(() =>
        {
            _form = HostWindowHelper.CreateChildForm(hostWindow, monitor.Width, monitor.Height);
            _pictureBox = new PictureBox
            {
                Dock = DockStyle.Fill,
                SizeMode = PictureBoxSizeMode.StretchImage,
                Image = Image.FromFile(imagePath)
            };
            _form.Controls.Add(_pictureBox);
        });
    }

    public void Play() { }

    public void Pause() { }

    public void Stop() =>
        PlayerUiThread.Invoke(() =>
        {
            _pictureBox?.Image?.Dispose();
            if (_pictureBox != null)
                _pictureBox.Image = null;
        });

    public void Resize(MonitorInfo monitor) =>
        PlayerUiThread.Invoke(() => _form?.SetBounds(0, 0, monitor.Width, monitor.Height));

    public void Dispose()
    {
        if (_disposed)
            return;

        PlayerUiThread.Invoke(() =>
        {
            Stop();
            _form?.Dispose();
            _form = null;
            _pictureBox = null;
        });
        _disposed = true;
    }
}
