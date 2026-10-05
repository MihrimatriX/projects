using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using EkranKaydi.Services;
using EkranKaydi.ViewModels;

namespace EkranKaydi.Views;

public partial class RecorderWindow : Window
{
    private const double MinSelW = 120;
    private const double MinSelH = 80;

    private readonly MainViewModel _mainViewModel;
    private readonly FfmpegService _ffmpeg = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(1) };

    private double _dpiX = 1;
    private double _dpiY = 1;
    private int _secondsElapsed;
    private bool _isRecording;

    private Rect _selection = new(180, 120, 640, 400);
    private Point _dragStart;
    private Point _selStart;
    private string? _resizeHandle;
    private bool _draggingSel;
    private bool _drawingSel;
    private bool _resizing;
    private Rect _resizeStartRect;

    public RecorderWindow(MainViewModel mainViewModel)
    {
        InitializeComponent();
        _mainViewModel = mainViewModel;
        _timer.Tick += (_, _) =>
        {
            _secondsElapsed++;
            var t = TimeSpan.FromSeconds(_secondsElapsed);
            TxtRecTime.Text = $"{(int)t.TotalHours:D2}:{t.Minutes:D2}:{t.Seconds:D2}";
        };
        // Kayıt sırasında Alt+F4 ile kapanırsa ffmpeg arkada çalışmaya devam etmesin
        Closed += (_, _) => { if (_isRecording) _ = _ffmpeg.StopRecordingAsync(); };
    }

    public void ToggleFromHotkey()
    {
        if (_isRecording) StopRecord_Click(this, new RoutedEventArgs());
        else StartRecord_Click(this, new RoutedEventArgs());
    }

    private void Window_Loaded(object sender, RoutedEventArgs e)
    {
        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;

        var source = PresentationSource.FromVisual(this);
        if (source?.CompositionTarget != null)
        {
            _dpiX = source.CompositionTarget.TransformToDevice.M11;
            _dpiY = source.CompositionTarget.TransformToDevice.M22;
        }

        UpdateOverlay();
        UpdateSelectionVisuals();
        UpdateCursorBadge();
        SizeChanged += (_, _) => UpdateOverlay();

        RootGrid.MouseMove += RootGrid_MouseMove;
        RootGrid.MouseLeftButtonUp += RootGrid_MouseLeftButtonUp;
    }

    private void RootGrid_MouseMove(object sender, MouseEventArgs e)
    {
        if (_resizing) HandleResize(e.GetPosition(RootGrid));
        else if (_draggingSel && !_isRecording) DragSelection(e.GetPosition(RootGrid));
    }

    private void RootGrid_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        _drawingSel = false;
        _draggingSel = false;
        _resizing = false;
        _resizeHandle = null;
        DimOverlayPath.ReleaseMouseCapture();
        SelectionFrame.ReleaseMouseCapture();
        Mouse.Capture(null);
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (_isRecording)
        {
            if (e.Key == Key.R && Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Alt))
            {
                e.Handled = true;
                StopRecord_Click(this, new RoutedEventArgs());
            }
            return;
        }

        if (e.Key == Key.Enter) { e.Handled = true; StartRecord_Click(this, new RoutedEventArgs()); }
        if (e.Key == Key.Escape) { e.Handled = true; Cancel_Click(this, new RoutedEventArgs()); }
        if (e.Key == Key.R) { e.Handled = true; StartRecord_Click(this, new RoutedEventArgs()); }
    }

    private void UpdateOverlay()
    {
        var full = new RectangleGeometry(new Rect(0, 0, ActualWidth, ActualHeight));
        var hole = new RectangleGeometry(_selection);
        DimOverlayPath.Data = new CombinedGeometry(GeometryCombineMode.Exclude, full, hole);
        Canvas.SetLeft(DimOverlayPath, 0);
        Canvas.SetTop(DimOverlayPath, 0);
    }

    private void UpdateSelectionVisuals()
    {
        Canvas.SetLeft(SelectionFrame, _selection.X);
        Canvas.SetTop(SelectionFrame, _selection.Y);
        SelectionFrame.Width = _selection.Width;
        SelectionFrame.Height = _selection.Height;

        Canvas.SetLeft(SizeLabelHost, _selection.X);
        Canvas.SetTop(SizeLabelHost, _selection.Y - 28);
        Canvas.SetLeft(TxtCursorBadge, _selection.Right - 80);
        Canvas.SetTop(TxtCursorBadge, _selection.Bottom + 6);

        PlaceHandle(HandleNw, _selection.Left, _selection.Top);
        PlaceHandle(HandleNe, _selection.Right, _selection.Top);
        PlaceHandle(HandleSw, _selection.Left, _selection.Bottom);
        PlaceHandle(HandleSe, _selection.Right, _selection.Bottom);

        TxtSizeLabel.Text = $"{(int)_selection.Width} × {(int)_selection.Height}";
        TxtRecMeta.Text = $"{(int)_selection.Width}×{(int)_selection.Height} · {GetFps()} FPS · {GetFormat()}";

        UpdateOverlay();
    }

    private static void PlaceHandle(Rectangle handle, double x, double y)
    {
        Canvas.SetLeft(handle, x - 5);
        Canvas.SetTop(handle, y - 5);
    }

    private void Overlay_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (_isRecording) return;
        _drawingSel = true;
        _dragStart = e.GetPosition(RootGrid);
        _selection = new Rect(_dragStart.X, _dragStart.Y, 0, 0);
        UpdateSelectionVisuals();
        DimOverlayPath.CaptureMouse();
        Mouse.Capture(RootGrid);
    }

    private void Overlay_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_drawingSel) return;
        var p = e.GetPosition(RootGrid);
        var x = Math.Min(_dragStart.X, p.X);
        var y = Math.Min(_dragStart.Y, p.Y);
        var w = Math.Max(MinSelW, Math.Abs(p.X - _dragStart.X));
        var h = Math.Max(MinSelH, Math.Abs(p.Y - _dragStart.Y));
        _selection = new Rect(x, y, w, h);
        UpdateSelectionVisuals();
    }

    private void Overlay_MouseLeftButtonUp(object sender, MouseButtonEventArgs e) => _drawingSel = false;

    private void Selection_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (_isRecording) return;
        _draggingSel = true;
        _dragStart = e.GetPosition(RootGrid);
        _selStart = new Point(_selection.X, _selection.Y);
        Mouse.Capture(RootGrid);
        e.Handled = true;
    }

    private void DragSelection(Point p)
    {
        var dx = p.X - _dragStart.X;
        var dy = p.Y - _dragStart.Y;
        _selection = new Rect(
            Clamp(_selStart.X + dx, 0, ActualWidth - _selection.Width),
            Clamp(_selStart.Y + dy, 0, ActualHeight - _selection.Height),
            _selection.Width, _selection.Height);
        UpdateSelectionVisuals();
    }

    private void HandleResize(Point p)
    {
        if (_resizeHandle == null) return;
        var dx = p.X - _dragStart.X;
        var dy = p.Y - _dragStart.Y;
        var rect = _resizeStartRect;
        var l = rect.Left;
        var t = rect.Top;
        var w = rect.Width;
        var h = rect.Height;

        if (_resizeHandle.Contains('e')) w = Math.Max(MinSelW, w + dx);
        if (_resizeHandle.Contains('w')) { w = Math.Max(MinSelW, w - dx); l = rect.Left + dx; }
        if (_resizeHandle.Contains('s')) h = Math.Max(MinSelH, h + dy);
        if (_resizeHandle.Contains('n')) { h = Math.Max(MinSelH, h - dy); t = rect.Top + dy; }

        _selection = new Rect(l, t, w, h);
        UpdateSelectionVisuals();
    }

    private void Handle_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (_isRecording) return;
        _resizing = true;
        _resizeHandle = (sender as FrameworkElement)?.Tag as string;
        _dragStart = e.GetPosition(RootGrid);
        _resizeStartRect = _selection;
        Mouse.Capture(RootGrid);
        e.Handled = true;
    }

    private void CursorToggle_Changed(object sender, RoutedEventArgs e) => UpdateCursorBadge();

    private void UpdateCursorBadge()
    {
        var on = ChkCursor.IsChecked == true;
        TxtCursorBadge.Text = on ? "İmleç: açık" : "İmleç: kapalı";
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();

    private void StartRecord_Click(object sender, RoutedEventArgs e)
    {
        if (_isRecording) return;

        var (px, py, pw, ph) = GetPhysicalRegion();
        if (pw <= 100 || ph <= 100)
        {
            MessageBox.Show("Kayıt alanı çok küçük.", "Hata", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var tempMp4 = AppPaths.TempRecordingPath;
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(tempMp4)!);
        if (File.Exists(tempMp4)) try { File.Delete(tempMp4); } catch { }

        try
        {
            _ffmpeg.StartRecording(tempMp4, px, py, pw, ph, GetFps(), ChkCursor.IsChecked == true);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Kayıt başlatılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        _isRecording = true;
        _secondsElapsed = 0;
        TxtRecTime.Text = "00:00:00";

        SetupToolbar.Visibility = Visibility.Collapsed;
        HintBar.Visibility = Visibility.Collapsed;
        HandleNw.Visibility = HandleNe.Visibility = HandleSw.Visibility = HandleSe.Visibility = Visibility.Collapsed;
        SelectionFrame.StrokeDashArray = null;
        SelectionFrame.Fill = Brushes.Transparent;
        RecordFloatBar.Visibility = Visibility.Visible;
        ShortcutHint.Visibility = Visibility.Visible;
        _timer.Start();
    }

    private async void StopRecord_Click(object sender, RoutedEventArgs e)
    {
        if (!_isRecording) return;
        _timer.Stop();
        _isRecording = false;
        Cursor = Cursors.Wait;

        await _ffmpeg.StopRecordingAsync();
        Cursor = Cursors.Arrow;

        var tempMp4 = AppPaths.TempRecordingPath;
        if (File.Exists(tempMp4))
        {
            new TrimWindow(tempMp4, GetFormat(), GetFps(), _mainViewModel).Show();
        }
        else
        {
            MessageBox.Show("Kayıt dosyası bulunamadı.", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
        }

        Close();
    }

    // WPF koordinatları DIP'tir, gdigrab fiziksel piksel bekler -> DPI ölçeğiyle çarpılır.
    // Ofset birincil monitörün sol üstüne göredir; soldaki monitörlerde negatif olabilir.
    private (int px, int py, int pw, int ph) GetPhysicalRegion()
    {
        var screenX = Left + _selection.X;
        var screenY = Top + _selection.Y;
        var pw = (int)Math.Round(_selection.Width * _dpiX);
        var ph = (int)Math.Round(_selection.Height * _dpiY);
        if (pw % 2 != 0) pw--;
        if (ph % 2 != 0) ph--;
        return (
            (int)Math.Round(screenX * _dpiX),
            (int)Math.Round(screenY * _dpiY),
            pw, ph);
    }

    private int GetFps()
    {
        if (CbFps.SelectedItem is ComboBoxItem item && int.TryParse(item.Content.ToString(), out var fps))
            return fps;
        return 15;
    }

    private string GetFormat() =>
        (CbFormat.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "GIF";

    private static double Clamp(double v, double min, double max) => Math.Max(min, Math.Min(max, v));
}
