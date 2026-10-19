using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using EkranGoruntusu.Services;
using EkranGoruntusu.ViewModels;
using Brushes = System.Windows.Media.Brushes;
using Color = System.Windows.Media.Color;
using Image = System.Windows.Controls.Image;
using Point = System.Windows.Point;
using Rectangle = System.Drawing.Rectangle;

namespace EkranGoruntusu.Views;

public partial class EditorWindow : Window
{
    private static readonly Color Accent = Color.FromRgb(0x0E, 0xA5, 0xE9);
    private static readonly Color Danger = Color.FromRgb(0xEF, 0x44, 0x44);

    private readonly Bitmap _croppedBitmap;
    private readonly MainViewModel _vm;
    private readonly Stack<object> _history = new();

    private enum ToolMode { Pen, Arrow, Rectangle, Text, Blur }

    private ToolMode _currentMode = ToolMode.Arrow;
    private Point _startPoint;
    private bool _isDrawing;
    private UIElement? _previewElement;
    private bool _ocrExpanded;
    private bool _saved;

    public EditorWindow(Bitmap croppedBitmap, MainViewModel mainViewModel)
    {
        InitializeComponent();
        _croppedBitmap = new Bitmap(croppedBitmap);
        _vm = mainViewModel;

        CroppedImage.Source = ToBitmapSource(_croppedBitmap);
        MetaLabel.Text = $"{_croppedBitmap.Width} × {_croppedBitmap.Height} · PNG";

        EditorInkCanvas.DefaultDrawingAttributes.Color = Accent;
        EditorInkCanvas.DefaultDrawingAttributes.Width = 3;
        EditorInkCanvas.DefaultDrawingAttributes.Height = 3;
        EditorInkCanvas.StrokeCollected += (_, e) => { _history.Push(e.Stroke); BtnUndo.IsEnabled = true; };
    }

    private static BitmapSource ToBitmapSource(Bitmap bitmap)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        var data = bitmap.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadOnly, bitmap.PixelFormat);
        try
        {
            return BitmapSource.Create(bitmap.Width, bitmap.Height, 96, 96, PixelFormats.Bgra32, null,
                data.Scan0, data.Stride * rect.Height, data.Stride);
        }
        finally { bitmap.UnlockBits(data); }
    }

    private void Tool_Checked(object sender, RoutedEventArgs e)
    {
        // İlk araç XAML yüklenirken işaretlenir; tuval henüz oluşmamıştır.
        if (sender is not RadioButton { Tag: string tag } || EditorInkCanvas == null) return;

        _currentMode = tag switch
        {
            "Pen" => ToolMode.Pen,
            "Rect" => ToolMode.Rectangle,
            "Text" => ToolMode.Text,
            "Blur" => ToolMode.Blur,
            _ => ToolMode.Arrow
        };
        EditorInkCanvas.EditingMode = _currentMode == ToolMode.Pen ? InkCanvasEditingMode.Ink : InkCanvasEditingMode.None;
    }

    private void BtnUndo_Click(object sender, RoutedEventArgs e)
    {
        if (_history.Count == 0) return;
        var last = _history.Pop();
        if (last is System.Windows.Ink.Stroke stroke) EditorInkCanvas.Strokes.Remove(stroke);
        else if (last is UIElement el) EditorInkCanvas.Children.Remove(el);
        BtnUndo.IsEnabled = _history.Count > 0;
    }

    private void InkCanvas_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (_currentMode == ToolMode.Pen || e.ChangedButton != MouseButton.Left) return;
        _startPoint = e.GetPosition(EditorInkCanvas);
        _isDrawing = true;
        EditorInkCanvas.CaptureMouse();
    }

    private void InkCanvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_isDrawing || _currentMode == ToolMode.Pen) return;
        var current = e.GetPosition(EditorInkCanvas);
        if (_previewElement != null) EditorInkCanvas.Children.Remove(_previewElement);

        _previewElement = _currentMode switch
        {
            ToolMode.Rectangle => MakeRectPreview(_startPoint, current, Accent, false),
            ToolMode.Arrow => CreateArrowPath(_startPoint, current, Accent),
            ToolMode.Blur => MakeRectPreview(_startPoint, current, Danger, true),
            _ => null
        };
        if (_previewElement != null) EditorInkCanvas.Children.Add(_previewElement);
    }

    private static System.Windows.Shapes.Rectangle MakeRectPreview(Point start, Point current, Color stroke, bool blur)
    {
        var rect = new System.Windows.Shapes.Rectangle
        {
            Stroke = new SolidColorBrush(stroke),
            StrokeThickness = blur ? 2 : 3,
            Fill = blur ? new SolidColorBrush(Color.FromArgb(30, stroke.R, stroke.G, stroke.B)) : Brushes.Transparent,
            Width = Math.Abs(current.X - start.X),
            Height = Math.Abs(current.Y - start.Y)
        };
        InkCanvas.SetLeft(rect, Math.Min(start.X, current.X));
        InkCanvas.SetTop(rect, Math.Min(start.Y, current.Y));
        return rect;
    }

    private void InkCanvas_MouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!_isDrawing || _currentMode == ToolMode.Pen) return;
        _isDrawing = false;
        EditorInkCanvas.ReleaseMouseCapture();
        if (_previewElement != null) { EditorInkCanvas.Children.Remove(_previewElement); _previewElement = null; }

        var end = e.GetPosition(EditorInkCanvas);
        switch (_currentMode)
        {
            case ToolMode.Rectangle:
                CommitRect(_startPoint, end, Accent, false);
                break;
            case ToolMode.Arrow:
                if (Distance(_startPoint, end) > 5)
                {
                    var arrow = CreateArrowPath(_startPoint, end, Accent);
                    EditorInkCanvas.Children.Add(arrow);
                    _history.Push(arrow);
                    BtnUndo.IsEnabled = true;
                }
                break;
            case ToolMode.Text:
                AddTextAt(end);
                break;
            case ToolMode.Blur:
                CommitRect(_startPoint, end, Danger, true);
                break;
        }
    }

    private void CommitRect(Point start, Point end, Color stroke, bool blur)
    {
        var w = Math.Abs(end.X - start.X);
        var h = Math.Abs(end.Y - start.Y);
        if (w <= 2 || h <= 2) return;

        if (blur) { ApplyBlurSelection(start, end); return; }

        var rect = MakeRectPreview(start, end, stroke, false);
        EditorInkCanvas.Children.Add(rect);
        _history.Push(rect);
        BtnUndo.IsEnabled = true;
    }

    private static double Distance(Point a, Point b) =>
        Math.Sqrt(Math.Pow(b.X - a.X, 2) + Math.Pow(b.Y - a.Y, 2));

    private System.Windows.Shapes.Path CreateArrowPath(Point start, Point end, Color color)
    {
        var path = new System.Windows.Shapes.Path
        {
            Stroke = new SolidColorBrush(color),
            StrokeThickness = 3,
            Fill = new SolidColorBrush(color)
        };
        var geometry = new PathGeometry();
        var line = new PathFigure { StartPoint = start, IsClosed = false };
        line.Segments.Add(new LineSegment(end, true));
        geometry.Figures.Add(line);

        var angle = Math.Atan2(end.Y - start.Y, end.X - start.X);
        const double head = 15, spread = Math.PI / 6;
        var p1 = new Point(end.X - head * Math.Cos(angle - spread), end.Y - head * Math.Sin(angle - spread));
        var p2 = new Point(end.X - head * Math.Cos(angle + spread), end.Y - head * Math.Sin(angle + spread));
        var headFig = new PathFigure { StartPoint = p1, IsClosed = true };
        headFig.Segments.Add(new LineSegment(end, true));
        headFig.Segments.Add(new LineSegment(p2, true));
        geometry.Figures.Add(headFig);
        path.Data = geometry;
        return path;
    }

    private void AddTextAt(Point point)
    {
        var box = new TextBox
        {
            Background = Brushes.Transparent,
            Foreground = new SolidColorBrush(Accent),
            CaretBrush = new SolidColorBrush(Accent),
            BorderBrush = new SolidColorBrush(Accent),
            BorderThickness = new Thickness(1),
            MinWidth = 80, FontSize = 14, FontWeight = FontWeights.SemiBold
        };
        InkCanvas.SetLeft(box, point.X);
        InkCanvas.SetTop(box, point.Y);
        EditorInkCanvas.Children.Add(box);
        box.Focus();
        box.LostFocus += (_, _) => CommitText(box);
        box.KeyDown += (_, ev) => { if (ev.Key == Key.Enter) CommitText(box); };
    }

    private void CommitText(TextBox box)
    {
        if (!EditorInkCanvas.Children.Contains(box)) return;
        var text = box.Text.Trim();
        var x = InkCanvas.GetLeft(box);
        var y = InkCanvas.GetTop(box);
        EditorInkCanvas.Children.Remove(box);
        if (string.IsNullOrEmpty(text)) return;

        var block = new TextBlock
        {
            Text = text,
            Foreground = box.Foreground,
            FontSize = box.FontSize,
            FontWeight = box.FontWeight
        };
        InkCanvas.SetLeft(block, x);
        InkCanvas.SetTop(block, y);
        EditorInkCanvas.Children.Add(block);
        _history.Push(block);
        BtnUndo.IsEnabled = true;
    }

    private void ApplyBlurSelection(Point start, Point end)
    {
        var x = (int)Math.Round(Math.Min(start.X, end.X));
        var y = (int)Math.Round(Math.Min(start.Y, end.Y));
        var w = (int)Math.Round(Math.Abs(start.X - end.X));
        var h = (int)Math.Round(Math.Abs(start.Y - end.Y));
        x = Math.Clamp(x, 0, _croppedBitmap.Width - 1);
        y = Math.Clamp(y, 0, _croppedBitmap.Height - 1);
        w = Math.Clamp(w, 1, _croppedBitmap.Width - x);
        h = Math.Clamp(h, 1, _croppedBitmap.Height - y);

        try
        {
            using var sub = new Bitmap(w, h);
            using (var g = Graphics.FromImage(sub))
                g.DrawImage(_croppedBitmap, new Rectangle(0, 0, w, h), new Rectangle(x, y, w, h), GraphicsUnit.Pixel);

            using var blurred = Pixelate(sub, 12);
            var img = new Image { Source = ToBitmapSource(blurred), Width = w, Height = h, Stretch = Stretch.Fill };
            InkCanvas.SetLeft(img, x);
            InkCanvas.SetTop(img, y);
            EditorInkCanvas.Children.Add(img);
            _history.Push(img);
            BtnUndo.IsEnabled = true;
        }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Blur error: {ex.Message}"); }
    }

    // Bloğun ortalama rengiyle doldurur (geri döndürülemez maskeleme). Piksel tamponu üzerinde çalışır:
    // eski GetPixel döngüsü büyük bölgelerde arayüzü saniyelerce donduruyordu.
    internal static Bitmap Pixelate(Bitmap original, int pixelSize)
    {
        var result = new Bitmap(original.Width, original.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(result))
            g.DrawImage(original, 0, 0, original.Width, original.Height);

        var rect = new Rectangle(0, 0, result.Width, result.Height);
        var data = result.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadWrite, result.PixelFormat);
        try
        {
            var stride = data.Stride;
            var buf = new byte[stride * result.Height];
            System.Runtime.InteropServices.Marshal.Copy(data.Scan0, buf, 0, buf.Length);

            for (var py = 0; py < result.Height; py += pixelSize)
            for (var px = 0; px < result.Width; px += pixelSize)
            {
                var w = Math.Min(pixelSize, result.Width - px);
                var h = Math.Min(pixelSize, result.Height - py);
                long b = 0, gVal = 0, r = 0;
                for (var yy = py; yy < py + h; yy++)
                for (var xx = px; xx < px + w; xx++)
                {
                    var i = yy * stride + xx * 4;
                    b += buf[i]; gVal += buf[i + 1]; r += buf[i + 2];
                }
                var count = w * h;
                for (var yy = py; yy < py + h; yy++)
                for (var xx = px; xx < px + w; xx++)
                {
                    var i = yy * stride + xx * 4;
                    buf[i] = (byte)(b / count); buf[i + 1] = (byte)(gVal / count); buf[i + 2] = (byte)(r / count); buf[i + 3] = 255;
                }
            }

            System.Runtime.InteropServices.Marshal.Copy(buf, 0, data.Scan0, buf.Length);
        }
        finally { result.UnlockBits(data); }
        return result;
    }

    private byte[] GetCanvasBytes()
    {
        var rtb = new RenderTargetBitmap(_croppedBitmap.Width, _croppedBitmap.Height, 96, 96, PixelFormats.Pbgra32);
        var old = EditorInkCanvas.EditingMode;
        EditorInkCanvas.EditingMode = InkCanvasEditingMode.None;
        rtb.Render(CanvasContainer);
        EditorInkCanvas.EditingMode = old;

        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(rtb));
        using var ms = new MemoryStream();
        encoder.Save(ms);
        return ms.ToArray();
    }

    private void OcrHeader_Click(object sender, MouseButtonEventArgs e) => SetOcrPanel(!_ocrExpanded);

    private void SetOcrPanel(bool open)
    {
        _ocrExpanded = open;
        OcrBody.Visibility = open ? Visibility.Visible : Visibility.Collapsed;
        OcrToggleIcon.Text = open ? "▴" : "▾";
    }

    private async void BtnOcr_Click(object sender, RoutedEventArgs e)
    {
        SetOcrPanel(true);
        OcrLoadingPanel.Visibility = Visibility.Visible;
        OcrTextBox.Visibility = Visibility.Collapsed;
        OcrEmptyText.Visibility = Visibility.Collapsed;
        BtnCopyOcr.Visibility = Visibility.Collapsed;

        var text = await OcrService.RecognizeTextFromBytesAsync(GetCanvasBytes());
        OcrLoadingPanel.Visibility = Visibility.Collapsed;

        if (string.IsNullOrWhiteSpace(text))
        {
            OcrEmptyText.Visibility = Visibility.Visible;
            return;
        }

        OcrTextBox.Text = text;
        OcrTextBox.Visibility = Visibility.Visible;
        BtnCopyOcr.Visibility = Visibility.Visible;
    }

    private void BtnCopyOcr_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(OcrTextBox.Text)) return;
        try
        {
            Clipboard.SetText(OcrTextBox.Text);
            EditorStatus.Text = "Metin panoya kopyalandı";
        }
        catch (System.Runtime.InteropServices.ExternalException) { EditorStatus.Text = "Pano meşgul, tekrar deneyin"; }
    }

    private void BtnCopy_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var bytes = GetCanvasBytes();
            using var ms = new MemoryStream(bytes);
            var bi = new BitmapImage();
            bi.BeginInit();
            bi.StreamSource = ms;
            bi.CacheOption = BitmapCacheOption.OnLoad;
            bi.EndInit();
            Clipboard.SetImage(bi);
            EditorStatus.Text = "Panoya kopyalandı";
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Panoya kopyalama hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private async void BtnSave_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Cursor = Cursors.Wait;
            BtnSave.IsEnabled = false; // OCR sürerken ikinci kayıt başlamasın
            EditorStatus.Text = "Kaydediliyor…";
            var bytes = GetCanvasBytes();
            var filename = _vm.Settings.FormatFilename(DateTime.Now);
            var fullPath = System.IO.Path.Combine(_vm.Database.ScreenshotsFolder, filename);
            // Aynı saniyede ikinci kayıt eski dosyanın üzerine yazmasın (DB'de ImagePath UNIQUE)
            for (var i = 1; File.Exists(fullPath); i++)
                fullPath = System.IO.Path.Combine(_vm.Database.ScreenshotsFolder,
                    $"{System.IO.Path.GetFileNameWithoutExtension(filename)}_{i}.png");
            await File.WriteAllBytesAsync(fullPath, bytes);
            var ocrText = await OcrService.RecognizeTextFromBytesAsync(bytes);
            _vm.SaveNewCapture(fullPath, ocrText);
            _saved = true;
            Close();
        }
        catch (Exception ex)
        {
            BtnSave.IsEnabled = true;
            EditorStatus.Text = string.Empty;
            MessageBox.Show(this, $"Kaydetme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally { Cursor = Cursors.Arrow; }
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        // Metin kutusuna yazarken rakamlar araç değiştirmesin
        if (e.Key is >= Key.D1 and <= Key.D5 && e.OriginalSource is not TextBox)
        {
            var idx = (int)e.Key - (int)Key.D1;
            var buttons = new[] { BtnArrow, BtnRect, BtnPen, BtnText, BtnBlur };
            buttons[idx].IsChecked = true;
        }
        if (e.Key == Key.C && Keyboard.Modifiers == ModifierKeys.Control && e.OriginalSource is not TextBox)
        {
            e.Handled = true;
            BtnCopy_Click(this, new RoutedEventArgs());
        }
        if (e.Key == Key.Z && Keyboard.Modifiers == ModifierKeys.Control) BtnUndo_Click(this, new RoutedEventArgs());
        if (e.Key == Key.S && Keyboard.Modifiers == ModifierKeys.Control && BtnSave.IsEnabled) { e.Handled = true; BtnSave_Click(this, new RoutedEventArgs()); }
    }

    // Esc önizleme aşamasında: çizimden sonra odak InkCanvas'tayken KeyDown'a ulaşmıyordu (Esc çalışmıyordu).
    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Escape || e.OriginalSource is TextBox) return;
        e.Handled = true;
        Close();
    }

    // İşaretlemeler kaydedilmeden (Esc / pencereyi kapat) kaybolmasın.
    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_saved && _history.Count > 0 &&
            MessageBox.Show(this, "İşaretlemeler kaydedilmedi. Düzenleyici kapatılsın mı?", "Kaydedilmedi",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            e.Cancel = true;
        base.OnClosing(e);
    }

    protected override void OnClosed(EventArgs e)
    {
        _croppedBitmap.Dispose();
        base.OnClosed(e);
    }
}
