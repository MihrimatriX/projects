using System.Windows;
using System.Windows.Input;
using EkranGoruntusu.ViewModels;
using EkranGoruntusu.Views;

namespace EkranGoruntusu;

public partial class MainWindow : Window
{
    private SettingsWindow? _settingsWindow;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (DataContext is not MainViewModel vm) return;

        vm.RequestStartCapture += () =>
        {
            // Ana pencere yalnızca yakalama sırasında gizlidir; kısayola tekrar basılınca ikinci overlay açılmasın
            if (!IsVisible) return;
            Hide();
            System.Threading.Thread.Sleep(200);
            var capture = new CaptureWindow(vm);
            capture.Closed += (_, _) =>
            {
                Show();
                WindowState = WindowState.Normal;
                Activate();
            };
            capture.Show();
        };

        vm.RequestOpenEditor += bitmap =>
        {
            using (bitmap) new EditorWindow(bitmap, vm).Show(); // düzenleyici kendi kopyasını tutar
        };

        vm.RequestShowMain += () =>
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
        };

        vm.RequestOpenSettings += () =>
        {
            if (_settingsWindow is { IsVisible: true })
            {
                _settingsWindow.Activate();
                return;
            }

            _settingsWindow = new SettingsWindow(vm) { Owner = this };
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
            _settingsWindow.Show();
        };
    }

    // Ctrl+F arama kutusuna gider; aramadayken Esc temizler (diğer kısayollar Window.InputBindings'te).
    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control)
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
            e.Handled = true;
        }
        else if (e.Key == Key.Escape && SearchBox.IsKeyboardFocusWithin && SearchBox.Text.Length > 0)
        {
            SearchBox.Clear();
            e.Handled = true;
        }
    }

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
