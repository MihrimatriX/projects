using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using EkranRenkSecici.Helpers;
using EkranRenkSecici.Models;
using EkranRenkSecici.Services;
using Color = System.Windows.Media.Color;
using WpfBrush = System.Windows.Media.Brush;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfSize = System.Windows.Size;

namespace EkranRenkSecici.Views;

public partial class SelectionWindow : Window
{
    private static readonly CopyFormat[] Formats = Enum.GetValues<CopyFormat>();

    private readonly IReadOnlyList<Color> _history;
    private Bitmap? _screenBitmap;
    private WriteableBitmap? _zoomBitmap;
    private Color _currentColor;
    private double _dpiX = 1.0;
    private double _dpiY = 1.0;
    private int _sampleSize = 3;
    private int _zoomLevel = 8;
    private int _formatIndex;
    private bool _gridVisible;

    public event Action<Color>? ColorSelected;

    public SelectionWindow(IReadOnlyList<Color>? history = null)
    {
        _history = history ?? Array.Empty<Color>();
        CaptureScreen();
        InitializeComponent();
        Loaded += OnLoaded;
        Closed += (_, _) => _screenBitmap?.Dispose();
    }

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    private string? _captureError;

    // Ekran görüntüsü overlay pencere gösterilmeden ÖNCE alınır; aksi halde yarı saydam
    // karartma katmanı da yakalanır ve seçilen renkler koyulaşır.
    // SM_XVIRTUALSCREEN(76)..SM_CYVIRTUALSCREEN(79): tüm monitörleri kapsayan alan, fiziksel piksel.
    private void CaptureScreen()
    {
        try
        {
            int left = GetSystemMetrics(76), top = GetSystemMetrics(77);
            _screenBitmap = new Bitmap(GetSystemMetrics(78), GetSystemMetrics(79));
            using var g = Graphics.FromImage(_screenBitmap);
            g.CopyFromScreen(left, top, 0, 0, _screenBitmap.Size);
        }
        catch (Exception ex)
        {
            _screenBitmap?.Dispose();
            _screenBitmap = null;
            _captureError = ex.Message;
        }
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var settings = SettingsService.Instance.Current;
        _sampleSize = settings.SampleSize;
        _zoomLevel = settings.MagnifierZoom;
        _formatIndex = Array.IndexOf(Formats, settings.DefaultCopyFormat);
        if (_formatIndex < 0) _formatIndex = 0;

        UpdateSampleButtons();
        UpdateFormatTabs();
        RenderHistoryRow();

        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;

        DimOverlay.Width = Width;
        DimOverlay.Height = Height;

        // Pencere tüm sanal ekranı (çoklu monitör) kaplar; DPI ölçeği fare→piksel dönüşümü için okunur.
        var source = PresentationSource.FromVisual(this);
        if (source?.CompositionTarget != null)
        {
            _dpiX = source.CompositionTarget.TransformToDevice.M11;
            _dpiY = source.CompositionTarget.TransformToDevice.M22;
        }

        if (_screenBitmap == null)
        {
            MessageBox.Show($"Ekran yakalama hatası: {_captureError}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            Close();
            return;
        }

        _zoomBitmap = new WriteableBitmap(_zoomLevel, _zoomLevel, 96, 96, PixelFormats.Bgr32, null);
        ZoomImage.Source = _zoomBitmap;

        PositionHintBar();
        UpdateAtPoint(Mouse.GetPosition(this));
    }

    private void RenderHistoryRow()
    {
        HistoryRow.Children.Clear();
        for (var i = 0; i < 10; i++)
        {
            if (i < _history.Count)
            {
                var color = _history[i];
                var swatch = new Border
                {
                    Width = 24,
                    Height = 24,
                    CornerRadius = new CornerRadius(4),
                    Background = new SolidColorBrush(color),
                    BorderBrush = (WpfBrush)FindResource("SwatchBorderBrush"),
                    BorderThickness = new Thickness(1),
                    Margin = new Thickness(3, 0, 3, 0),
                    Cursor = Cursors.Hand,
                    ToolTip = ColorHelper.ToHex(color)
                };
                swatch.MouseLeftButtonDown += (_, e) =>
                {
                    e.Handled = true;
                    _currentColor = color;
                    UpdateDisplay();
                };
                HistoryRow.Children.Add(swatch);
            }
            else
            {
                HistoryRow.Children.Add(new Border
                {
                    Width = 24,
                    Height = 24,
                    CornerRadius = new CornerRadius(4),
                    Background = new SolidColorBrush(Color.FromArgb(20, 255, 255, 255)),
                    BorderBrush = (WpfBrush)FindResource("BorderBrush"),
                    BorderThickness = new Thickness(1),
                    Margin = new Thickness(3, 0, 3, 0)
                });
            }
        }
    }

    private void PositionHintBar()
    {
        HintBar.Measure(new WpfSize(double.PositiveInfinity, double.PositiveInfinity));
        Canvas.SetLeft(HintBar, (Width - HintBar.DesiredSize.Width) / 2);
        Canvas.SetTop(HintBar, Height - HintBar.DesiredSize.Height - 24);
    }

    private void Window_MouseMove(object sender, MouseEventArgs e) => UpdateAtPoint(e.GetPosition(this));

    private void UpdateAtPoint(System.Windows.Point mousePos)
    {
        if (_screenBitmap == null) return;

        Canvas.SetLeft(MagnifierBorder, mousePos.X - MagnifierBorder.Width / 2);
        Canvas.SetTop(MagnifierBorder, mousePos.Y - MagnifierBorder.Height / 2);

        var panelY = mousePos.Y + 80;
        var panelX = mousePos.X;
        ColorPanel.Measure(new WpfSize(280, double.PositiveInfinity));
        var panelH = ColorPanel.DesiredSize.Height;
        if (panelY + panelH > Height) panelY = mousePos.Y - panelH - 20;
        if (panelX + 140 > Width) panelX = Width - 150;
        if (panelX - 140 < 0) panelX = 150;
        Canvas.SetLeft(ColorPanel, panelX - ColorPanel.Width / 2);
        Canvas.SetTop(ColorPanel, panelY);

        // Fare konumu WPF birimi (DIP); DPI ölçeğiyle çarpılıp yakalanan bitmap'teki fiziksel piksele çevrilir.
        var px = Math.Clamp((int)Math.Round(mousePos.X * _dpiX), 0, _screenBitmap.Width - 1);
        var py = Math.Clamp((int)Math.Round(mousePos.Y * _dpiY), 0, _screenBitmap.Height - 1);

        _currentColor = ColorHelper.GetAverageColor(_screenBitmap, px, py, _sampleSize);
        UpdateDisplay();
        RenderMagnifier(px, py);
        MetaText.Text = $"X: {Math.Round(mousePos.X)} · Y: {Math.Round(mousePos.Y)} · {_zoomLevel}× zoom · {_sampleSize}×{_sampleSize} ortalama";
    }

    private void UpdateDisplay()
    {
        SwatchTop.Background = new SolidColorBrush(_currentColor);
        ColorValueText.Text = ColorHelper.FormatForCopy(_currentColor, Formats[_formatIndex]);
    }

    private void RenderMagnifier(int centerX, int centerY)
    {
        if (_screenBitmap == null || _zoomBitmap == null) return;
        try
        {
            ColorHelper.CopyRegionToWriteableBitmap(_screenBitmap, _zoomBitmap, centerX, centerY, _zoomLevel);
        }
        catch { /* edge pixels */ }
    }

    private void Window_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left) ConfirmSelection();
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Escape: Close(); break;
            case Key.Enter: ConfirmSelection(); break;
            case Key.Tab:
                e.Handled = true;
                SetFormat(_formatIndex + (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) ? -1 : 1));
                break;
            case Key.Left: e.Handled = true; SetFormat(_formatIndex - 1); break;
            case Key.Right: e.Handled = true; SetFormat(_formatIndex + 1); break;
            case Key.C when Keyboard.Modifiers == ModifierKeys.None:
                SetFormat(Array.IndexOf(Formats, CopyFormat.CSS));
                break;
            case Key.Space:
                e.Handled = true;
                _gridVisible = !_gridVisible;
                MagGrid.Opacity = _gridVisible ? 1 : 0;
                break;
            case Key.D1 or Key.NumPad1: SetSampleSize(1); break;
            case Key.D3 or Key.NumPad3: SetSampleSize(3); break;
            case Key.D5 or Key.NumPad5: SetSampleSize(5); break;
        }
    }

    private void FormatTab_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && int.TryParse(btn.Tag?.ToString(), out var idx))
            SetFormat(idx);
    }

    private void SampleButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && int.TryParse(btn.Tag?.ToString(), out var size))
            SetSampleSize(size);
    }

    private void SetFormat(int index)
    {
        _formatIndex = (index % Formats.Length + Formats.Length) % Formats.Length;
        UpdateFormatTabs();
        ColorValueText.Text = ColorHelper.FormatForCopy(_currentColor, Formats[_formatIndex]);
    }

    private void UpdateFormatTabs()
    {
        var tabs = new[] { TabHex, TabRgb, TabHsl, TabOklch, TabCss };
        for (var i = 0; i < tabs.Length; i++)
        {
            var active = i == _formatIndex;
            tabs[i].Foreground = active
                ? (WpfBrush)FindResource("TextBrush")
                : (WpfBrush)FindResource("SubTextBrush");
            tabs[i].BorderBrush = active
                ? (WpfBrush)FindResource("AccentBrush")
                : WpfBrushes.Transparent;
        }
    }

    private void SetSampleSize(int size)
    {
        _sampleSize = size;
        UpdateSampleButtons();
        UpdateAtPoint(Mouse.GetPosition(this));
    }

    private void UpdateSampleButtons()
    {
        SetSegmentActive(BtnSample1, _sampleSize == 1);
        SetSegmentActive(BtnSample3, _sampleSize == 3);
        SetSegmentActive(BtnSample5, _sampleSize == 5);
    }

    private void SetSegmentActive(Button btn, bool active)
    {
        btn.Foreground = active
            ? new SolidColorBrush(Colors.White)
            : (WpfBrush)FindResource("SubTextBrush");
        btn.Background = active
            ? new SolidColorBrush(Color.FromArgb(51, 59, 130, 246))
            : WpfBrushes.Transparent;
        btn.BorderBrush = active
            ? (WpfBrush)FindResource("AccentBrush")
            : WpfBrushes.Transparent;
    }

    private void ConfirmSelection()
    {
        try { Clipboard.SetText(ColorHelper.FormatForCopy(_currentColor, Formats[_formatIndex])); } catch { /* busy */ }
        ColorSelected?.Invoke(_currentColor);
        Close();
    }
}
