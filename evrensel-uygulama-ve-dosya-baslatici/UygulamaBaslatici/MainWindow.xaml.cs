using System.Windows;
using System.Windows.Input;
using NHotkey;
using NHotkey.Wpf;
using UygulamaBaslatici.ViewModels;

namespace UygulamaBaslatici;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;
    private bool _hotkeyRegistered;

    public MainWindow()
    {
        InitializeComponent();
        _vm = new MainViewModel();
        _vm.RequestHide += () => Dispatcher.BeginInvoke(Hide);
        DataContext = _vm;
        PositionWindow();
        // Pencere başlangıçta hiç gösterilmediği için SourceInitialized tetiklenmez; NHotkey kendi gizli
        // mesaj penceresini kullandığından kısayol doğrudan burada kaydedilir.
        RegisterGlobalHotkey();
    }

    private void RegisterGlobalHotkey()
    {
        if (_hotkeyRegistered) return;
        try
        {
            HotkeyManager.Current.AddOrReplace("ToggleLauncher", Key.Space, ModifierKeys.Alt, OnGlobalHotkey);
            _hotkeyRegistered = true;
        }
        catch (Exception)
        {
            // Engelleyen uyarı kutusu yerine palet uyarıyla hemen açılır; exe yeniden çalıştırılınca da açılır.
            _vm.HotkeyFailed = true;
            Dispatcher.BeginInvoke(ShowPalette);
        }
    }

    private void OnGlobalHotkey(object? sender, HotkeyEventArgs e)
    {
        e.Handled = true;
        Dispatcher.BeginInvoke(ToggleVisibility);
    }

    private void ToggleVisibility()
    {
        if (IsVisible) Hide();
        else ShowPalette();
    }

    internal void ShowPalette()
    {
        Show();
        PositionWindow();
        Activate();
        Topmost = true;
        Topmost = false;
        Focus();
        SearchBox.Focus();
        Keyboard.Focus(SearchBox);
        SearchBox.SelectAll();
        _vm.ExecuteSearch();
    }

    private void PositionWindow()
    {
        Left = (SystemParameters.PrimaryScreenWidth - Width) / 2; // ActualWidth ilk gosterimden once 0
        Top = SystemParameters.PrimaryScreenHeight * 0.18;
    }

    private void Window_Deactivated(object sender, EventArgs e)
    {
        if (!_vm.IsScanning) Hide();
    }

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        // Windows Alt+Space sistem menüsünü engelle, toggle yap
        if (e.Key == Key.System && e.SystemKey == Key.Space)
        {
            e.Handled = true;
            ToggleVisibility();
            return;
        }

        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            Hide();
        }
        else if (e.Key == Key.Enter && Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
        {
            e.Handled = true;
            _vm.OpenItemLocation(_vm.SelectedItem);
        }
        else if (e.Key == Key.Enter)
        {
            e.Handled = true;
            if (_vm.SelectedItem != null)
                _vm.LaunchItemCommand.Execute(_vm.SelectedItem);
            else if (_vm.ShowEmptyState)
                _vm.LaunchWebSearchCommand.Execute(null);
        }
    }

    private void SearchBox_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (ResultsList.Items.Count == 0) return;

        if (e.Key == Key.Down && ResultsList.SelectedIndex < ResultsList.Items.Count - 1)
        {
            ResultsList.SelectedIndex++;
            ResultsList.ScrollIntoView(ResultsList.SelectedItem);
            e.Handled = true;
        }
        else if (e.Key == Key.Up && ResultsList.SelectedIndex > 0)
        {
            ResultsList.SelectedIndex--;
            ResultsList.ScrollIntoView(ResultsList.SelectedItem);
            e.Handled = true;
        }
    }

    private void ResultsList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (_vm.SelectedItem != null)
            _vm.LaunchItemCommand.Execute(_vm.SelectedItem);
    }

    protected override void OnClosed(EventArgs e)
    {
        _vm.Dispose();
        base.OnClosed(e);
        // ShutdownMode=OnExplicitShutdown: pencere (Alt+F4) kapanınca süreç arka planda asılı kalmasın.
        Application.Current.Shutdown();
    }
}
