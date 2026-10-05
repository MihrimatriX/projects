using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Threading;
using EkranKaydi.Helpers;
using EkranKaydi.Services;
using EkranKaydi.ViewModels;

namespace EkranKaydi.Views;

public partial class TrimWindow : Window
{
    private readonly string _sourcePath;
    private readonly MainViewModel _mainViewModel;
    private readonly bool _isExistingRecording;
    private readonly bool _deleteSourceOnClose;

    private string _exportFormat;
    private int _fps;
    private double _durationSeconds;
    private int _videoWidth;
    private int _videoHeight;
    private bool _isPlaying;
    private bool _isExporting;

    private readonly DispatcherTimer _playTimer = new() { Interval = TimeSpan.FromMilliseconds(100) };

    public TrimWindow(string sourcePath, string targetFormat, int fps, MainViewModel mainViewModel, bool isExistingRecording = false)
    {
        InitializeComponent();
        AppIcon.Apply(this);

        _sourcePath = sourcePath;
        _exportFormat = targetFormat;
        _fps = fps;
        _mainViewModel = mainViewModel;
        _isExistingRecording = isExistingRecording;
        _deleteSourceOnClose = !isExistingRecording;

        SetFormatToggle(_exportFormat);
        UpdateExportButtonLabel();
        VideoPlayer.Source = new Uri(_sourcePath);

        Loaded += TrimWindow_Loaded;
        Closed += (_, _) => { if (_deleteSourceOnClose) TryDelete(_sourcePath); };
        _playTimer.Tick += PlayTimer_Tick;
    }

    private async void TrimWindow_Loaded(object sender, RoutedEventArgs e)
    {
        var info = await FfmpegService.GetMediaInfoAsync(_sourcePath);
        _durationSeconds = info.DurationSeconds;
        _videoWidth = info.Width;
        _videoHeight = info.Height;

        if (_durationSeconds > 0)
            InitTimeline();
        else
            VideoPlayer.Play(); // triggers MediaOpened fallback

        _playTimer.Start();
    }

    private void InitTimeline()
    {
        TxtMeta.Text = $"{_videoWidth}×{_videoHeight} · Orijinal süre: {_durationSeconds:F1} sn · Hedef: {_exportFormat.ToUpperInvariant()}";
        TxtTimelineHeader.Text = $"Timeline · {_fps} FPS · {(int)(_durationSeconds * _fps)} kare";
        TxtMidLabel.Text = $"{_durationSeconds / 2:F1}s";
        TxtEndLabel.Text = $"{_durationSeconds:F1}s";

        Timeline.Duration = _durationSeconds;
        Timeline.TrimStart = 0;
        Timeline.TrimEnd = _durationSeconds;
        Timeline.Playhead = 0;

        UpdateTrimUi();
    }

    private void VideoPlayer_MediaOpened(object sender, RoutedEventArgs e)
    {
        if (_durationSeconds > 0) return;
        if (!VideoPlayer.NaturalDuration.HasTimeSpan) return;

        _durationSeconds = VideoPlayer.NaturalDuration.TimeSpan.TotalSeconds;
        _videoWidth = (int)VideoPlayer.NaturalVideoWidth;
        _videoHeight = (int)VideoPlayer.NaturalVideoHeight;
        InitTimeline();
    }

    private void PlayTimer_Tick(object? sender, EventArgs e)
    {
        if (_isPlaying && VideoPlayer.Source != null)
        {
            Timeline.Playhead = VideoPlayer.Position.TotalSeconds;
            if (VideoPlayer.Position.TotalSeconds >= Timeline.TrimEnd - 0.05)
                VideoPlayer.Position = TimeSpan.FromSeconds(Timeline.TrimStart);
        }
        UpdateTimeDisplay();
    }

    private void UpdateTimeDisplay() =>
        TxtTimeDisplay.Text = $"{FormatTime(Timeline.Playhead)} / {FormatTime(_durationSeconds)}";

    private static string FormatTime(double seconds)
    {
        var t = TimeSpan.FromSeconds(Math.Max(0, seconds));
        return $"{(int)t.TotalMinutes:D2}:{t.Seconds:D2}.{t.Milliseconds / 100}";
    }

    private void Timeline_TrimChanged(object sender, EventArgs e) => UpdateTrimUi();

    private void Timeline_PlayheadChanged(object sender, EventArgs e)
    {
        VideoPlayer.Position = TimeSpan.FromSeconds(Timeline.Playhead);
        UpdateTimeDisplay();
    }

    private void UpdateTrimUi()
    {
        TxtTrimInfo.Text = $"Kırp: {Timeline.TrimStart:F1}s - {Timeline.TrimEnd:F1}s";
        UpdateSizeEstimate();
        BtnExport.IsEnabled = !_isExporting && Timeline.TrimEnd - Timeline.TrimStart >= 0.2;
    }

    private void UpdateSizeEstimate()
    {
        if (!File.Exists(_sourcePath) || _durationSeconds <= 0)
        {
            TxtSizeEstimate.Text = string.Empty;
            return;
        }

        var trimLen = Timeline.TrimEnd - Timeline.TrimStart;
        var ratio = Math.Clamp(trimLen / _durationSeconds, 0, 1);
        var sourceBytes = new FileInfo(_sourcePath).Length;
        var estimated = _exportFormat.Equals("GIF", StringComparison.OrdinalIgnoreCase)
            ? (long)Math.Max(1, sourceBytes * ratio * 1.8)
            : (long)Math.Max(1, sourceBytes * ratio);

        TxtSizeEstimate.Text = $"Tahmini boyut: ~{FormatBytes(estimated)}";
        WarnBanner.Visibility = _exportFormat.Equals("GIF", StringComparison.OrdinalIgnoreCase) && estimated > 8 * 1024 * 1024
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
        return $"{bytes / (1024.0 * 1024.0):F1} MB";
    }

    private void BtnPlayOverlay_Click(object sender, RoutedEventArgs e) => TogglePlay();

    private void BtnPlay_Click(object sender, RoutedEventArgs e)
    {
        if (!_isPlaying) TogglePlay();
    }

    private void BtnPause_Click(object sender, RoutedEventArgs e)
    {
        if (_isPlaying) TogglePlay();
    }

    private void TogglePlay()
    {
        _isPlaying = !_isPlaying;
        BtnPlayOverlay.Visibility = _isPlaying ? Visibility.Collapsed : Visibility.Visible;
        PreviewBorder.BorderBrush = _isPlaying
            ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(0x8C, 0x60, 0xA5, 0xFA))
            : (System.Windows.Media.Brush)FindResource("BorderBrush");

        if (_isPlaying)
        {
            if (VideoPlayer.Position.TotalSeconds < Timeline.TrimStart || VideoPlayer.Position.TotalSeconds >= Timeline.TrimEnd)
                VideoPlayer.Position = TimeSpan.FromSeconds(Timeline.TrimStart);
            VideoPlayer.Play();
        }
        else
        {
            VideoPlayer.Pause();
        }
    }

    private void Format_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not ToggleButton btn || btn.Tag is not string fmt) return;
        if (btn.IsChecked != true)
        {
            btn.IsChecked = true;
            return;
        }

        _exportFormat = fmt;
        SetFormatToggle(fmt);
        TxtMeta.Text = $"{_videoWidth}×{_videoHeight} · Orijinal süre: {_durationSeconds:F1} sn · Hedef: {_exportFormat.ToUpperInvariant()}";
        UpdateExportButtonLabel();
        UpdateSizeEstimate();
    }

    private void SetFormatToggle(string fmt)
    {
        BtnFmtGif.IsChecked = fmt.Equals("GIF", StringComparison.OrdinalIgnoreCase);
        BtnFmtMp4.IsChecked = fmt.Equals("MP4", StringComparison.OrdinalIgnoreCase);
    }

    private void UpdateExportButtonLabel() =>
        BtnExport.Content = _exportFormat.Equals("MP4", StringComparison.OrdinalIgnoreCase) ? "MP4 Oluştur" : "GIF Oluştur";

    private int GetSelectedFps()
    {
        if (CbFps.SelectedItem is ComboBoxItem item && int.TryParse(item.Content.ToString(), out var fps))
            return fps;
        return _fps;
    }

    private void CbFps_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _fps = GetSelectedFps();
        if (_durationSeconds > 0)
            TxtTimelineHeader.Text = $"Timeline · {_fps} FPS · {(int)(_durationSeconds * _fps)} kare";
        UpdateSizeEstimate();
    }

    private async void BtnExport_Click(object sender, RoutedEventArgs e)
    {
        if (_isExporting) return;

        var trimDuration = Timeline.TrimEnd - Timeline.TrimStart;
        if (trimDuration <= 0.2)
        {
            MessageBox.Show("Kırpılacak süre çok kısa.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        // ffmpeg yoksa önizlemeyi bozmadan kurulum talimatını göster
        if (!_mainViewModel.EnsureFfmpeg()) return;

        _isExporting = true;
        BtnExport.IsEnabled = false;
        ExportProgress.Visibility = Visibility.Visible;
        ExportProgress.Value = 0;
        ExportPanel.BorderBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(0x7A, 0x4A, 0xDE, 0x80));

        // MediaElement dosyayı kilitler — ffmpeg trim/GIF bu yüzden başarısız olur
        _playTimer.Stop();
        VideoPlayer.Stop();
        VideoPlayer.Source = null;
        _isPlaying = false;
        BtnPlayOverlay.Visibility = Visibility.Visible;

        if (_videoWidth <= 0 || _videoHeight <= 0)
        {
            var info = await FfmpegService.GetMediaInfoAsync(_sourcePath);
            _videoWidth = info.Width;
            _videoHeight = info.Height;
            _durationSeconds = info.DurationSeconds > 0 ? info.DurationSeconds : _durationSeconds;
        }

        if (_videoWidth <= 0)
            _videoWidth = 640;

        var progressTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(200) };
        progressTimer.Tick += (_, _) =>
        {
            if (ExportProgress.Value < 90)
                ExportProgress.Value += 8;
        };
        progressTimer.Start();

        try
        {
            var tempFolder = AppPaths.TempFolder;
            Directory.CreateDirectory(tempFolder);
            var trimmedMp4 = Path.Combine(tempFolder, $"trim_{Guid.NewGuid():N}.mp4");

            await FfmpegService.TrimVideoAsync(_sourcePath, trimmedMp4, Timeline.TrimStart, Timeline.TrimEnd);
            await _mainViewModel.SaveNewRecordingAsync(trimmedMp4, _exportFormat, trimDuration, _videoWidth, _videoHeight, GetSelectedFps());

            ExportProgress.Value = 100;
            BtnExport.Content = "Tamamlandı";
            await Task.Delay(400);
            Close();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Dışa aktarma hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            BtnExport.Content = UpdateExportButtonLabelText();
            BtnExport.IsEnabled = true;
            if (File.Exists(_sourcePath)) VideoPlayer.Source = new Uri(_sourcePath); // önizlemeyi geri getir
        }
        finally
        {
            progressTimer.Stop();
            _isExporting = false;
            ExportPanel.BorderBrush = (System.Windows.Media.Brush)FindResource("BorderBrush");
            if (IsLoaded)
                _playTimer.Start();
        }
    }

    private string UpdateExportButtonLabelText() =>
        _exportFormat.Equals("MP4", StringComparison.OrdinalIgnoreCase) ? "MP4 Oluştur" : "GIF Oluştur";

    private void BtnCancel_Click(object sender, RoutedEventArgs e)
    {
        if (_isExistingRecording)
        {
            Close();
            return;
        }

        if (MessageBox.Show("Kaydı iptal edip silmek istiyor musunuz?", "İptal", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            Close();
    }

    private static void TryDelete(string path)
    {
        if (!File.Exists(path)) return;
        try { File.Delete(path); } catch { }
    }

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e) => DragMove();
    private void Close_Click(object sender, RoutedEventArgs e) => BtnCancel_Click(sender, e);

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Space) { e.Handled = true; TogglePlay(); }
        if (e.Key == Key.S && Keyboard.Modifiers == ModifierKeys.Control) { e.Handled = true; BtnExport_Click(sender, e); }
    }
}
