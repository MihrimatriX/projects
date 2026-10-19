using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using ProjeLauncher.ViewModels;

namespace ProjeLauncher;

public partial class MainWindow : Window
{
    private const double MinCard = 290;

    public static readonly DependencyProperty CardWidthProperty =
        DependencyProperty.Register(nameof(CardWidth), typeof(double), typeof(MainWindow), new PropertyMetadata(320.0));
    public static readonly DependencyProperty CardImageHeightProperty =
        DependencyProperty.Register(nameof(CardImageHeight), typeof(double), typeof(MainWindow), new PropertyMetadata(170.0));

    public double CardWidth { get => (double)GetValue(CardWidthProperty); set => SetValue(CardWidthProperty, value); }
    public double CardImageHeight { get => (double)GetValue(CardImageHeightProperty); set => SetValue(CardImageHeightProperty, value); }

    private readonly DispatcherTimer _runningTimer = new() { Interval = TimeSpan.FromSeconds(3) };

    public MainWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        // Dar pencerede kenar cubugu daralir, kartlara yer kalir.
        SizeChanged += (_, e) => SidebarColumn.Width = new GridLength(e.NewSize.Width < 960 ? 208 : 248);
        Vm.PropertyChanged += Vm_PropertyChanged;
        _runningTimer.Tick += async (_, _) => await Vm.UpdateRunningAsync();
    }

    private MainViewModel Vm => (MainViewModel)DataContext;

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        // Kucuk resimleri ekran DPI'sina gore coz: 200%'de net, 100%'de gereksiz buyuk degil.
        var dpi = VisualTreeHelper.GetDpi(this).DpiScaleX;
        Vm.ThumbWidth = (int)Math.Min(800, 360 * dpi);
        Vm.DetailImageWidth = (int)Math.Min(2560, 1100 * dpi);
        SearchBox.Focus();
        await Vm.RefreshAsync();
        _runningTimer.Start();
        await Vm.CheckToolchainsAsync();
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(MainViewModel.DetailProject)) return;
        // Gorunurluk degistikten sonra odagi tasi: detayda geri dugmesi, galeride secili kart.
        Dispatcher.BeginInvoke(DispatcherPriority.Input, () =>
        {
            if (Vm.DetailProject is not null)
            {
                DetailView.ScrollToTop();
                BackButton.Focus();
            }
            else if (!SearchBox.IsKeyboardFocusWithin)
            {
                FocusSelectedCard();
            }
        });
    }

    private void FocusSelectedCard()
    {
        var item = Vm.SelectedProject ?? (ProjectGrid.Items.Count > 0 ? ProjectGrid.Items[0] : null);
        if (item is null) return;
        ProjectGrid.ScrollIntoView(item);
        ProjectGrid.UpdateLayout();
        if (ProjectGrid.ItemContainerGenerator.ContainerFromItem(item) is ListBoxItem c) c.Focus();
    }

    private void ProjectGrid_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        // Kartlar satiri tam doldursun: sutun sayisi = sigan en genis tam sayi.
        var avail = ProjectGrid.ActualWidth - ProjectGrid.Padding.Left - ProjectGrid.Padding.Right - 14;
        if (avail <= 0) return;
        var cols = Math.Max(1, (int)(avail / MinCard));
        CardWidth = Math.Floor(avail / cols);
        CardImageHeight = Math.Round((CardWidth - 14) * 0.5625);
    }

    private void ProjectGrid_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is DependencyObject d && ItemsControl.ContainerFromElement(ProjectGrid, d) is ListBoxItem { DataContext: Models.ProjectEntry p })
            Vm.OpenDetailCommand.Execute(p);
    }

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        var ctrl = Keyboard.Modifiers.HasFlag(ModifierKeys.Control);
        switch (e.Key)
        {
            case Key.F when ctrl:
                Vm.DetailProject = null;
                SearchBox.Focus();
                SearchBox.SelectAll();
                break;
            case Key.F5:
                Vm.RefreshCommand.Execute(null);
                break;
            case Key.Escape:
                if (!Vm.ClearOne()) return;
                break;
            case Key.Enter when ctrl:
                Vm.OpenCommand.Execute(null);
                break;
            case Key.Enter when e.OriginalSource is ListBoxItem && ProjectGrid.IsKeyboardFocusWithin && Vm.SelectedProject is not null:
                Vm.OpenDetailCommand.Execute(null);
                break;
            case Key.Down when SearchBox.IsKeyboardFocused && ProjectGrid.Items.Count > 0:
                if (Vm.SelectedProject is null) Vm.SelectedProject = (Models.ProjectEntry)ProjectGrid.Items[0];
                FocusSelectedCard();
                break;
            case Key.Back when Vm.DetailProject is not null && e.OriginalSource is not TextBox:
            case Key.System when e.SystemKey == Key.Left && Vm.DetailProject is not null:
                Vm.DetailProject = null;
                break;
            default:
                return;
        }
        e.Handled = true;
    }
}
