using System;
using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using HizliDosyaArama.Models;
using HizliDosyaArama.ViewModels;
using Application = System.Windows.Application;

namespace HizliDosyaArama;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;
    private readonly DispatcherTimer _toastTimer;
    private System.Windows.Forms.NotifyIcon? _tray;

    public MainWindow()
    {
        InitializeComponent();

        _vm = new MainViewModel();
        _vm.RequestShow += OnRequestShow;
        _vm.RequestHide += OnRequestHide;
        DataContext = _vm;

        _toastTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1500) };
        _toastTimer.Tick += (_, _) =>
        {
            _toastTimer.Stop();
            _vm.HideToast();
        };

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(MainViewModel.ShowToast) && _vm.ShowToast)
            {
                _toastTimer.Stop();
                _toastTimer.Start();
            }
        };

        SetupTrayIcon();
        Hide();
    }

    private void SetupTrayIcon()
    {
        var iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "assets", "app.ico");
        System.Drawing.Icon? icon = File.Exists(iconPath)
            ? new System.Drawing.Icon(iconPath)
            : System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? Application.ResourceAssembly.Location);

        _tray = new System.Windows.Forms.NotifyIcon
        {
            Icon = icon ?? SystemIcons.Application,
            Text = "Hızlı Dosya Arama — Alt+F",
            Visible = true
        };

        var menu = new System.Windows.Forms.ContextMenuStrip();
        menu.Items.Add("Aç (Alt+F)", null, (_, _) => Dispatcher.BeginInvoke(OnRequestShow));
        menu.Items.Add("Yeniden indeksle", null, (_, _) => Dispatcher.BeginInvoke(() => _vm.StartIndexingCommand.Execute(null)));
        menu.Items.Add(new System.Windows.Forms.ToolStripSeparator());
        menu.Items.Add("Çıkış", null, (_, _) => Dispatcher.BeginInvoke(ExitApp));

        _tray.ContextMenuStrip = menu;
        _tray.DoubleClick += (_, _) => Dispatcher.BeginInvoke(OnRequestShow);
    }

    private void ExitApp()
    {
        if (_tray is not null)
        {
            _tray.Visible = false;
            _tray.Dispose();
            _tray = null;
        }
        Application.Current.Shutdown();
    }

    protected override void OnClosed(EventArgs e)
    {
        if (_tray is not null)
        {
            _tray.Visible = false;
            _tray.Dispose();
            _tray = null;
        }
        base.OnClosed(e);
    }

    public void ShowPalette() => OnRequestShow();

    private void OnRequestShow()
    {
        Show();
        Activate();
        SearchBox.Focus();
        SearchBox.SelectAll();
        _vm.ExecuteSearch();
    }

    private void OnRequestHide()
    {
        Hide();
        _vm.HideToast();
    }

    private void Window_Deactivated(object? sender, EventArgs e)
    {
        // İndeksleme sırasında pencereyi kapatma; aksi halde odak kaybında hemen kapanır
        if (!_vm.IsIndexing && IsVisible)
            Hide();
    }

    private void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Hide();
            e.Handled = true;
            return;
        }

        if (e.Key != Key.Enter || _vm.SelectedItem is null) return;

        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
            _vm.OpenFolderCommand.Execute(_vm.SelectedItem);
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift))
            _vm.CopyPathCommand.Execute(_vm.SelectedItem);
        else
            _vm.OpenFileCommand.Execute(_vm.SelectedItem);

        e.Handled = true;
    }

    private void SearchBox_PreviewKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (ResultsList.Items.Count == 0) return;

        if (e.Key == Key.Down)
        {
            if (ResultsList.SelectedIndex < ResultsList.Items.Count - 1)
            {
                ResultsList.SelectedIndex++;
                ResultsList.ScrollIntoView(ResultsList.SelectedItem);
            }
            e.Handled = true;
        }
        else if (e.Key == Key.Up)
        {
            if (ResultsList.SelectedIndex > 0)
            {
                ResultsList.SelectedIndex--;
                ResultsList.ScrollIntoView(ResultsList.SelectedItem);
            }
            e.Handled = true;
        }
    }

    private void ResultsList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (_vm.SelectedItem is not null)
            _vm.OpenFileCommand.Execute(_vm.SelectedItem);
    }

    private void ResultsList_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is not DependencyObject source) return;
        var item = ItemsControl.ContainerFromElement(ResultsList, source) as ListBoxItem;
        if (item?.DataContext is FileItem file)
            _vm.SelectedItem = file;
    }
}
