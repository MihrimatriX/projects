using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using EkranGoruntusu.ViewModels;
using Point = System.Windows.Point;

namespace EkranGoruntusu.Views;

public partial class CaptureWindow : Window
{
    private readonly MainViewModel _vm;
    private Bitmap? _screenBitmap;
    private Point _startPoint;
    private bool _isDragging;
    private bool _hasSelection;
    private double _dpiX = 1;
    private double _dpiY = 1;

    public CaptureWindow(MainViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
    }

    private void Window_Loaded(object sender, RoutedEventArgs e)
    {
        if (PresentationSource.FromVisual(this)?.CompositionTarget is { } target)
        {
            _dpiX = target.TransformToDevice.M11;
            _dpiY = target.TransformToDevice.M22;
        }

        // Overlay'in kendisi görüntüye girmesin diye önce gizlenir, sonra tüm sanal ekran (bütün monitörler) kopyalanır.
        // WPF koordinatları DIP'tir; GDI piksel ister, bu yüzden DPI ölçeğiyle çarpılır (pencere de sanal ekranı kaplar).
        Hide();
        System.Threading.Thread.Sleep(200);

        var left = (int)Math.Round(SystemParameters.VirtualScreenLeft * _dpiX);
        var top = (int)Math.Round(SystemParameters.VirtualScreenTop * _dpiY);
        var width = (int)Math.Round(SystemParameters.VirtualScreenWidth * _dpiX);
        var height = (int)Math.Round(SystemParameters.VirtualScreenHeight * _dpiY);

        try
        {
            _screenBitmap = new Bitmap(width, height);
            using var g = Graphics.FromImage(_screenBitmap);
            g.CopyFromScreen(left, top, 0, 0, _screenBitmap.Size);
            BackgroundImage.Source = ToImageSource(_screenBitmap);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Ekran yakalama hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            Close();
            return;
        }

        Show();
        Focus();
    }

    private static ImageSource ToImageSource(Bitmap bitmap)
    {
        using var ms = new MemoryStream();
        bitmap.Save(ms, System.Drawing.Imaging.ImageFormat.Bmp);
        ms.Position = 0;
        var bi = new BitmapImage();
        bi.BeginInit();
        bi.StreamSource = ms;
        bi.CacheOption = BitmapCacheOption.OnLoad;
        bi.EndInit();
        bi.Freeze();
        return bi;
    }

    // Checked olayları: fare tıklaması ve UIA (SelectionItem) aynı yoldan geçer.
    private void ModeRegion_Click(object sender, RoutedEventArgs e)
    {
        if (SelectionBorder == null) return; // XAML yüklenirken ilk işaretleme
        ClearSelection();
    }

    private void ModeScreen_Click(object sender, RoutedEventArgs e)
    {
        SelectionBorder.Width = ActualWidth;
        SelectionBorder.Height = ActualHeight;
        Canvas.SetLeft(SelectionBorder, 0);
        Canvas.SetTop(SelectionBorder, 0);
        SelectionBorder.Visibility = Visibility.Visible;
        _hasSelection = true;
        UpdateSizeTag(SelectionBorder.Width, SelectionBorder.Height);
    }

    private void Canvas_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left || ModeScreen.IsChecked == true) return;

        _startPoint = e.GetPosition(SelectionCanvas);
        _isDragging = true;
        SelectionBorder.Width = 0;
        SelectionBorder.Height = 0;
        SelectionBorder.Visibility = Visibility.Visible;
        Canvas.SetLeft(SelectionBorder, _startPoint.X);
        Canvas.SetTop(SelectionBorder, _startPoint.Y);
        _hasSelection = false;
    }

    private void Canvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_isDragging) return;

        var current = e.GetPosition(SelectionCanvas);
        var x = Math.Min(_startPoint.X, current.X);
        var y = Math.Min(_startPoint.Y, current.Y);
        var w = Math.Abs(_startPoint.X - current.X);
        var h = Math.Abs(_startPoint.Y - current.Y);

        Canvas.SetLeft(SelectionBorder, x);
        Canvas.SetTop(SelectionBorder, y);
        SelectionBorder.Width = w;
        SelectionBorder.Height = h;
        UpdateSizeTag(w, h);
    }

    private void Canvas_MouseUp(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left || !_isDragging) return;
        _isDragging = false;
        _hasSelection = SelectionBorder.Width >= 16 && SelectionBorder.Height >= 16;
    }

    private void UpdateSizeTag(double w, double h) =>
        SizeTag.Text = $"{Math.Round(w)} × {Math.Round(h)}";

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape) Close();
        else if (e.Key == Key.Enter) ConfirmSelection();
    }

    private void Confirm_Click(object sender, RoutedEventArgs e) => ConfirmSelection();
    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();

    private void Window_MouseRightButtonUp(object sender, MouseButtonEventArgs e) => Close();

    private void ConfirmSelection()
    {
        if (!_hasSelection || _screenBitmap == null) return;

        var x = Canvas.GetLeft(SelectionBorder);
        var y = Canvas.GetTop(SelectionBorder);
        var w = SelectionBorder.Width;
        var h = SelectionBorder.Height;

        if (w < 16 || h < 16) return;

        // Seçim DIP cinsinden; yakalanan bitmap'teki piksel konumuna çevir
        var px = Math.Clamp((int)Math.Round(x * _dpiX), 0, _screenBitmap.Width - 1);
        var py = Math.Clamp((int)Math.Round(y * _dpiY), 0, _screenBitmap.Height - 1);
        var pw = Math.Clamp((int)Math.Round(w * _dpiX), 1, _screenBitmap.Width - px);
        var ph = Math.Clamp((int)Math.Round(h * _dpiY), 1, _screenBitmap.Height - py);

        try
        {
            using var cropped = new Bitmap(pw, ph);
            using (var g = Graphics.FromImage(cropped))
                g.DrawImage(_screenBitmap, new Rectangle(0, 0, pw, ph), new Rectangle(px, py, pw, ph), GraphicsUnit.Pixel);

            var editor = new EditorWindow(cropped, _vm);
            // Önce kapat: Closed işleyicisi ana pencereyi geri getirip etkinleştirir; düzenleyici onun önünde açılmalı
            // (eskiden ana pencere düzenleyicinin üstüne geliyordu).
            Close();
            editor.Show();
            editor.Activate();
            return;
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Kırpma hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
        }

        Close();
    }

    private void ClearSelection()
    {
        SelectionBorder.Visibility = Visibility.Collapsed;
        _hasSelection = false;
    }

    protected override void OnClosed(EventArgs e)
    {
        _screenBitmap?.Dispose();
        _screenBitmap = null;
        base.OnClosed(e);
    }
}
