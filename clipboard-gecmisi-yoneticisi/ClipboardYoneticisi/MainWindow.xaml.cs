using System;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using ClipboardYoneticisi.Helpers;
using ClipboardYoneticisi.Models;
using ClipboardYoneticisi.Services;
using ClipboardYoneticisi.ViewModels;
using Hardcodet.Wpf.TaskbarNotification;
using Microsoft.Win32;

namespace ClipboardYoneticisi;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private bool _isExplicitShutdown;
    private bool _suppressPositionSave;

    public MainWindow()
    {
        InitializeComponent();

        _viewModel = new MainViewModel();
        _viewModel.RequestShow += ViewModel_RequestShow;
        _viewModel.RequestHide += ViewModel_RequestHide;
        _viewModel.RequestExit += ViewModel_RequestExit;
        _viewModel.RequestSettings += ViewModel_RequestSettings;
        _viewModel.RequestUnlock += ViewModel_RequestUnlock;
        _viewModel.RequestAbout += ViewModel_RequestAbout;
        _viewModel.RequestHelp += ViewModel_RequestHelp;
        _viewModel.RequestWelcome += ViewModel_RequestWelcome;
        _viewModel.RequestExportFile += ShowExportDialogAsync;
        _viewModel.RequestImportFile += ShowImportDialogAsync;
        _viewModel.RequestTrayNotification += ShowTrayNotification;
        _viewModel.RequestShowUpdate += info => new UpdateWindow(info) { Owner = IsVisible ? this : null }.ShowDialog();
        _viewModel.RequestCopyFlash += ShowCopyFlash;
        _viewModel.RequestReselect += ids =>
        {
            foreach (var item in _viewModel.History.Where(i => ids.Contains(i.Id) && !HistoryList.SelectedItems.Contains(i)))
                HistoryList.SelectedItems.Add(item);
        };
        _viewModel.IsWindowVisibleCheck = () => IsVisible;

        DataContext = _viewModel;
        // Kaynaktaki menu gorsel agacta degil: DataContext'i elle ver (tepsi ve menu dugmesi ortak kullanir).
        AppMenu.DataContext = _viewModel;

        try
        {
            var exePath = Environment.ProcessPath;
            if (!string.IsNullOrEmpty(exePath))
            {
                var icon = System.Drawing.Icon.ExtractAssociatedIcon(exePath);
                if (icon != null)
                    MyNotifyIcon.Icon = icon;
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Tray icon load failed: {ex.Message}");
        }

        // Gecici veri klasoruyle (test) calisan ornegin tepsi simgesi gercek ornekten ayirt edilebilsin.
        if (AppPaths.IsTestMode)
            MyNotifyIcon.ToolTipText += " (test)";

        PositionWindow();
        Loaded += MainWindow_Loaded;
        PreviewKeyDown += MainWindow_PreviewKeyDown;
        LocationChanged += MainWindow_LocationChanged;
    }

    private ContextMenu AppMenu => (ContextMenu)Resources["AppMenu"];

    private void MenuButton_Click(object sender, RoutedEventArgs e)
    {
        AppMenu.PlacementTarget = MenuButton;
        AppMenu.Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom;
        AppMenu.IsOpen = true;
    }

    private async void ShowCopyFlash()
    {
        CopyFlash.Visibility = Visibility.Visible;
        await Task.Delay(500);
        CopyFlash.Visibility = Visibility.Collapsed;
    }

    private void MainWindow_LocationChanged(object? sender, EventArgs e)
    {
        if (_suppressPositionSave || !IsVisible)
            return;

        var settings = SettingsService.Instance.Settings;
        settings.PanelLeft = Left;
        settings.PanelTop = Top;
        SettingsService.Instance.Save();
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        if (SettingsService.Instance.Settings.StartMinimized)
            Hide();

        if (_viewModel.IsLocked)
            ShowUnlockDialog();
        // ViewModel ctor'undaki RequestWelcome, olaya abone olunmadan tetiklendigi icin hic gorunmuyordu
        else if (!SettingsService.Instance.Settings.FirstRunCompleted)
            ViewModel_RequestWelcome();
    }

    private void MainWindow_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Hide();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.Down && SearchBox.IsKeyboardFocusWithin && _viewModel.History.Count > 0)
        {
            HistoryList.Focus();
            HistoryList.SelectedIndex = 0;
            e.Handled = true;
            return;
        }

        if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control)
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
            e.Handled = true;
            return;
        }

        // Arama kutusunda Ctrl+Z metni geri alir; baska yerde son silmeyi geri alir.
        if (e.Key == Key.Z && Keyboard.Modifiers == ModifierKeys.Control && !SearchBox.IsKeyboardFocusWithin)
        {
            _viewModel.UndoDeleteCommand.Execute(null);
            FocusSelectedRow();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.F1 || (e.Key == Key.OemQuestion && Keyboard.Modifiers == ModifierKeys.Shift))
        {
            _viewModel.OpenHelpCommand.Execute(null);
            e.Handled = true;
        }
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        _viewModel.MonitorService.AddHook(this);
    }

    private Task<string?> ShowExportDialogAsync()
    {
        var dialog = new SaveFileDialog
        {
            Filter = "JSON yedek (*.json)|*.json",
            FileName = $"clipboard-yedek-{DateTime.Now:yyyyMMdd-HHmm}.json"
        };
        // Test modu: diyalog gecici veri klasorunde acilsin; test asla kullanicinin Belgeler klasorune yazmasin.
        if (AppPaths.IsTestMode)
            dialog.InitialDirectory = AppPaths.DataFolder;

        return Task.FromResult(dialog.ShowDialog() == true ? dialog.FileName : null);
    }

    private Task<string?> ShowImportDialogAsync()
    {
        var dialog = new OpenFileDialog
        {
            Filter = "JSON yedek (*.json)|*.json"
        };
        if (AppPaths.IsTestMode)
            dialog.InitialDirectory = AppPaths.DataFolder;

        return Task.FromResult(dialog.ShowDialog() == true ? dialog.FileName : null);
    }

    private void ViewModel_RequestShow()
    {
        Show();
        PositionWindow();
        WindowState = WindowState.Normal;
        Activate();
        SearchBox.Focus();
        SearchBox.SelectAll();
    }

    private void ViewModel_RequestHide() => Hide();

    private void ViewModel_RequestExit()
    {
        _isExplicitShutdown = true;
        Close();
    }

    private void ViewModel_RequestSettings()
    {
        var settingsWindow = new SettingsWindow { Owner = IsVisible ? this : null };
        if (settingsWindow.ShowDialog() == true)
            _viewModel.OnSettingsSaved(settingsWindow.EncryptionChanged);
    }

    private void ViewModel_RequestUnlock() => ShowUnlockDialog();

    private void ViewModel_RequestAbout() =>
        new AboutWindow { Owner = IsVisible ? this : null }.ShowDialog();

    private void ViewModel_RequestHelp() =>
        new HelpWindow { Owner = IsVisible ? this : null }.ShowDialog();

    private void ViewModel_RequestWelcome()
    {
        new WelcomeWindow { Owner = IsVisible ? this : null }.ShowDialog();
        _viewModel.OnSettingsSaved(false);
    }

    private void ShowUnlockDialog()
    {
        var isSetup = !EncryptionService.Instance.HasPassword;
        var lockWindow = new LockWindow(isSetup) { Owner = IsVisible ? this : null };

        if (lockWindow.ShowDialog() == true &&
            !string.IsNullOrWhiteSpace(lockWindow.EnteredPassword) &&
            _viewModel.TryUnlock(lockWindow.EnteredPassword))
        {
            return;
        }

        if (_viewModel.IsLocked && !isSetup)
        {
            MessageBox.Show(
                "Parola hatalı veya oturum açılamadı.",
                "Kilit",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    private void PositionWindow()
    {
        _suppressPositionSave = true;
        try
        {
            var settings = SettingsService.Instance.Settings;
            if (settings.PanelLeft.HasValue && settings.PanelTop.HasValue)
            {
                Left = settings.PanelLeft.Value;
                Top = settings.PanelTop.Value;
                EnsureOnScreen();
                return;
            }

            var workingArea = SystemParameters.WorkArea;
            Left = workingArea.Right - Width;
            Top = workingArea.Top;
            Height = workingArea.Height;
        }
        finally
        {
            _suppressPositionSave = false;
        }
    }

    private void EnsureOnScreen()
    {
        var area = SystemParameters.WorkArea;
        if (Left + Width < area.Left + 80)
            Left = area.Right - Width;
        if (Top < area.Top)
            Top = area.Top;
        if (Left > area.Right - 80)
            Left = area.Right - Width;
        if (Top + Height > area.Bottom)
            Top = area.Bottom - Height;
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_isExplicitShutdown)
        {
            e.Cancel = true;
            Hide();
        }
        else
        {
            _viewModel.MonitorService.RemoveHook();
            MyNotifyIcon.Dispose();
            base.OnClosing(e);
        }
    }

    private void ListBox_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (_viewModel.SelectedItem != null)
            _viewModel.CopyItemCommand.Execute(_viewModel.SelectedItem);
    }

    private void ShowTrayNotification(string title, string message)
    {
        try
        {
            var preview = message.Length > 120 ? message[..117] + "…" : message;
            MyNotifyIcon.ShowBalloonTip(title, preview, BalloonIcon.Info);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Tray notification failed: {ex.Message}");
        }
    }

    private void HistoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var items = HistoryList.SelectedItems.Cast<ClipboardItem>().ToList();
        _viewModel.SetSelectedItems(items);
    }

    /// <summary>Liste yeniden kurulduktan sonra klavye odagini secili satira geri ver.</summary>
    private void FocusSelectedRow() => Dispatcher.BeginInvoke(() =>
    {
        if (HistoryList.SelectedItem is { } item &&
            HistoryList.ItemContainerGenerator.ContainerFromItem(item) is ListBoxItem row)
            row.Focus();
        else if (HistoryList.Items.Count > 0)
            HistoryList.Focus();
    }, System.Windows.Threading.DispatcherPriority.Loaded);

    private void ListBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.A && Keyboard.Modifiers == ModifierKeys.Control)
        {
            HistoryList.SelectAll();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.Enter && _viewModel.SelectedItem != null)
        {
            _viewModel.CopyItemCommand.Execute(_viewModel.SelectedItem);
            FocusSelectedRow();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.Delete && _viewModel.SelectedItem != null)
        {
            if (_viewModel.HasMultiSelection)
                _viewModel.DeleteSelectedItemsCommand.Execute(null);
            else
                _viewModel.DeleteItemCommand.Execute(_viewModel.SelectedItem);
            FocusSelectedRow();
            e.Handled = true;
            return;
        }

        if (e.Key == Key.P && Keyboard.Modifiers == ModifierKeys.Control && _viewModel.SelectedItem != null)
        {
            _viewModel.TogglePinCommand.Execute(_viewModel.SelectedItem);
            FocusSelectedRow();
            e.Handled = true;
        }
    }

    private void HistoryList_ContextMenuOpening(object sender, ContextMenuEventArgs e)
    {
        TransformMenu.Items.Clear();

        if (_viewModel.HasMultiSelection)
        {
            AddMenuItem($"Stack'e ekle ({_viewModel.SelectedItemsCount})", () =>
                _viewModel.AddSelectedToStackCommand.Execute(null));
            AddMenuItem($"Sil ({_viewModel.SelectedItemsCount})", () =>
                _viewModel.DeleteSelectedItemsCommand.Execute(null), danger: true);
            return;
        }

        if (HistoryList.SelectedItem is not ClipboardItem item)
        {
            e.Handled = true;
            return;
        }

        AddMenuItem("Panoya al", () => _viewModel.CopyItemCommand.Execute(item));

        if (item.HasOcrText)
            AddMenuItem("OCR metnini yapıştır", () => _viewModel.CopyOcrTextCommand.Execute(item));

        AddMenuItem("Stack'e ekle", () => _viewModel.AddToStackCommand.Execute(item));

        if (SnippetTransform.CanTransform(item.Type))
        {
            TransformMenu.Items.Add(new Separator());
            AddTransformItem(item, "Küçük harfe çevir", TransformType.Lowercase);
            AddTransformItem(item, "Boşlukları temizle", TransformType.Trim);
            AddTransformItem(item, "JSON biçimlendir", TransformType.JsonPretty);
            AddTransformItem(item, "Markdown link", TransformType.MarkdownLink);
            AddTransformItem(item, "Satır sonlarını kaldır", TransformType.RemoveLineBreaks);
        }

        TransformMenu.Items.Add(new Separator());
        AddMenuItem(item.IsPinned ? "Sabitlemeyi kaldır" : "Sabitle", () =>
            _viewModel.TogglePinCommand.Execute(item));
        AddMenuItem("Sil", () => _viewModel.DeleteItemCommand.Execute(item), danger: true);
    }

    private void AddMenuItem(string header, Action onClick, bool danger = false)
    {
        var menuItem = new MenuItem { Header = header };
        if (danger)
            menuItem.Foreground = (System.Windows.Media.Brush)FindResource("DangerTextBrush");
        menuItem.Click += (_, _) => onClick();
        TransformMenu.Items.Add(menuItem);
    }

    private void AddTransformItem(ClipboardItem item, string label, TransformType transform)
    {
        var menuItem = new MenuItem { Header = label };
        menuItem.Click += (_, _) => _viewModel.CopyItemWithTransform(item, transform);
        TransformMenu.Items.Add(menuItem);
    }
}
