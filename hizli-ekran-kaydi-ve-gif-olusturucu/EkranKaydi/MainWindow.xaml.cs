using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using EkranKaydi.Helpers;
using EkranKaydi.Models;
using EkranKaydi.ViewModels;
using EkranKaydi.Views;

namespace EkranKaydi;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        AppIcon.Apply(this);
        Loaded += OnLoaded;
    }

    private MainViewModel? Vm => DataContext as MainViewModel;

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (Vm is null) return;

        Vm.RequestStartRecording += () =>
        {
            // Ctrl+Alt+R global kısayolu (RegisterHotKey) kayıt penceresine KeyDown olarak ulaşmaz;
            // pencere zaten açıksa ikinci overlay açmak yerine kaydı başlat/durdur.
            var open = Application.Current.Windows.OfType<RecorderWindow>().FirstOrDefault();
            if (open != null) { open.ToggleFromHotkey(); return; }

            Hide();
            Dispatcher.BeginInvoke(() =>
            {
            var recorder = new RecorderWindow(Vm);
            recorder.Closed += (_, _) =>
            {
                Show();
                WindowState = WindowState.Normal;
                Activate();
                Vm.LoadRecordingsCommand.Execute(null);
                UpdatePreview(Vm.SelectedRecording);
            };
            recorder.Show();
            }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
        };

        Vm.RequestShowMain += () =>
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
            Vm.LoadRecordingsCommand.Execute(null);
            UpdatePreview(Vm.SelectedRecording);
        };

        Vm.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(MainViewModel.SelectedRecording))
                UpdatePreview(Vm.SelectedRecording);
        };

        UpdatePreview(Vm.SelectedRecording);
    }

    private void UpdatePreview(RecordingItem? item)
    {
        PreviewPlayer.Stop();
        PreviewPlayer.Source = null;
        PreviewImage.Source = null;

        if (item is null || !File.Exists(item.FilePath))
        {
            PreviewPlayer.Visibility = Visibility.Visible;
            PreviewImage.Visibility = Visibility.Collapsed;
            return;
        }

        if (item.Type.Equals("GIF", StringComparison.OrdinalIgnoreCase))
        {
            PreviewPlayer.Visibility = Visibility.Collapsed;
            PreviewImage.Visibility = Visibility.Visible;
            try
            {
                var bmp = new System.Windows.Media.Imaging.BitmapImage();
                bmp.BeginInit();
                bmp.CacheOption = System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;
                bmp.UriSource = new Uri(item.FilePath);
                bmp.EndInit();
                bmp.Freeze();
                PreviewImage.Source = bmp;
            }
            catch
            {
                PreviewImage.Source = item.Thumbnail;
            }
            return;
        }

        PreviewImage.Visibility = Visibility.Collapsed;
        PreviewPlayer.Visibility = Visibility.Visible;
        try
        {
            PreviewPlayer.Source = new Uri(item.FilePath);
            PreviewPlayer.Play();
        }
        catch
        {
            PreviewPlayer.Source = null;
        }
    }

    private void RecordingsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (Vm is null || RecordingsList.SelectedItem is not RecordingItem item) return;
        Vm.SelectedRecording = item;
        Vm.StatusMessage = "Kayıt seçildi";
    }

    private void RecordingsList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (RecordingsList.SelectedItem is RecordingItem item)
            Vm?.OpenRecordingCommand.Execute(item);
    }

    private static string? DroppedVideo(DragEventArgs e) =>
        (e.Data.GetData(DataFormats.FileDrop) as string[])?.FirstOrDefault(MainViewModel.IsSupportedVideo);

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = DroppedVideo(e) != null ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        var path = DroppedVideo(e);
        if (path != null) Vm?.OpenVideoForConversion(path);
        else if (Vm != null) Vm.StatusMessage = "Yalnızca video dosyaları bırakılabilir (MP4, MOV, MKV, AVI, WEBM, WMV).";
    }

    private void PreviewPlay_Click(object sender, RoutedEventArgs e) => PreviewPlayer.Play();
    private void PreviewPause_Click(object sender, RoutedEventArgs e) => PreviewPlayer.Pause();

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
            WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
        else
            DragMove();
    }

    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void Maximize_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
