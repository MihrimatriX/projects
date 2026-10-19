using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace EkranKaydi.Controls;

public partial class TrimTimeline : UserControl
{
    public static readonly DependencyProperty DurationProperty =
        DependencyProperty.Register(nameof(Duration), typeof(double), typeof(TrimTimeline),
            new PropertyMetadata(1.0, OnLayoutChanged));

    public static readonly DependencyProperty TrimStartProperty =
        DependencyProperty.Register(nameof(TrimStart), typeof(double), typeof(TrimTimeline),
            new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnTrimChanged));

    public static readonly DependencyProperty TrimEndProperty =
        DependencyProperty.Register(nameof(TrimEnd), typeof(double), typeof(TrimTimeline),
            new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnTrimChanged));

    public static readonly DependencyProperty PlayheadProperty =
        DependencyProperty.Register(nameof(Playhead), typeof(double), typeof(TrimTimeline),
            new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnLayoutChanged));

    private bool _draggingStart;
    private bool _draggingEnd;
    private bool _internalUpdate;

    public TrimTimeline()
    {
        InitializeComponent();
        Loaded += (_, _) => { InitThumbs(); Paint(); };
        SizeChanged += (_, _) => Paint();
    }

    public double Duration
    {
        get => (double)GetValue(DurationProperty);
        set => SetValue(DurationProperty, value);
    }

    public double TrimStart
    {
        get => (double)GetValue(TrimStartProperty);
        set => SetValue(TrimStartProperty, value);
    }

    public double TrimEnd
    {
        get => (double)GetValue(TrimEndProperty);
        set => SetValue(TrimEndProperty, value);
    }

    public double Playhead
    {
        get => (double)GetValue(PlayheadProperty);
        set => SetValue(PlayheadProperty, value);
    }

    public event EventHandler? TrimChanged;
    public event EventHandler? PlayheadChanged;

    private void InitThumbs()
    {
        var items = Enumerable.Range(0, 24).Select(i => i).ToList();
        ThumbStrip.ItemsSource = items;
    }

    private static void OnLayoutChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is TrimTimeline t) t.Paint();
    }

    private static void OnTrimChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is TrimTimeline t)
        {
            t.Paint();
            if (!t._internalUpdate)
                t.TrimChanged?.Invoke(t, EventArgs.Empty);
        }
    }

    private void Paint()
    {
        var w = TrackBorder.ActualWidth;
        if (w <= 0 || Duration <= 0) return;

        TrackCanvas.Width = w;
        TrackCanvas.Height = 64;
        ThumbStrip.Width = w;
        Canvas.SetLeft(ThumbStrip, 0);
        Canvas.SetTop(ThumbStrip, 0);
        ThumbStrip.Height = 64;

        var ls = Pct(TrimStart) * w;
        var le = Pct(TrimEnd) * w;

        Canvas.SetLeft(TrimRange, ls);
        TrimRange.Width = Math.Max(0, le - ls);
        TrimRange.Height = 64;

        Canvas.SetLeft(HandleStart, ls - 4);
        Canvas.SetLeft(HandleEnd, le - 4);
        Canvas.SetLeft(PlayheadMarker, Pct(Playhead) * w);

        TrackBorder.BorderBrush = _draggingStart || _draggingEnd
            ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(0x8C, 0x60, 0xA5, 0xFA))
            : (System.Windows.Media.Brush)FindResource("BorderBrush");
    }

    private double Pct(double sec) => Duration > 0 ? Math.Clamp(sec / Duration, 0, 1) : 0;

    private double SecFromX(double x)
    {
        var w = TrackCanvas.ActualWidth;
        if (w <= 0) return 0;
        return Math.Clamp(x / w, 0, 1) * Duration;
    }

    private void HandleStart_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _draggingStart = true;
        CaptureMouse();
        e.Handled = true;
    }

    private void HandleEnd_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _draggingEnd = true;
        CaptureMouse();
        e.Handled = true;
    }

    private void Track_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        var sec = SecFromX(e.GetPosition(TrackCanvas).X);
        _internalUpdate = true;
        Playhead = Math.Clamp(sec, TrimStart, TrimEnd);
        _internalUpdate = false;
        PlayheadChanged?.Invoke(this, EventArgs.Empty);
        Paint();
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        if (!_draggingStart && !_draggingEnd) return;

        var sec = SecFromX(e.GetPosition(TrackCanvas).X);
        _internalUpdate = true;

        if (_draggingStart)
            TrimStart = Math.Min(sec, TrimEnd - 0.2);
        else
            TrimEnd = Math.Max(sec, TrimStart + 0.2);

        _internalUpdate = false;
        Paint();
    }

    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
    {
        if (!_draggingStart && !_draggingEnd) return;
        _draggingStart = _draggingEnd = false;
        ReleaseMouseCapture();
        Paint();
    }
}
