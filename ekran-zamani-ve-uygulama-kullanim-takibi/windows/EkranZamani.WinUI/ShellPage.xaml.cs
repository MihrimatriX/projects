using EkranZamani_WinUI.Services;
using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class ShellPage : Page
{
    public DailyPageViewModel DailyViewModel { get; }
    private readonly Dictionary<string, Type> _routes = new()
    {
        ["daily"] = typeof(DailyPage),
        ["weekly"] = typeof(WeeklyPage),
        ["goals"] = typeof(GoalsPage),
        ["categories"] = typeof(CategoriesPage),
        ["settings"] = typeof(SettingsPage),
    };

    public ShellPage()
    {
        var queue = DispatcherQueue.GetForCurrentThread() ?? App.DispatcherQueue;
        DailyViewModel = new DailyPageViewModel(queue);
        InitializeComponent();
        DataContext = DailyViewModel;
        Loaded += OnLoaded;
        // DailyPage DataContext'i yapıcıda buradan alır; Navigate senkron olduğu için önce atanmalı.
        AppNavigation.DailyViewModel = DailyViewModel;
        NavigateTo("daily");
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        AppNavigation.Shell = this;
        AppNavigation.DailyViewModel = DailyViewModel;
        if (App.Window is MainWindow mw)
            mw.InitializeShell(DailyViewModel);
        UpdateTrackingFooter();
        AppTracking.Instance.Changed += UpdateTrackingFooter;
    }

    private void UpdateTrackingFooter()
    {
        var tracking = AppTracking.Instance;
        TrackingStatusText.Text = tracking.IsTracking ? "İzleniyor" : "Duraklatıldı";
        TrackingDot.Fill = new Microsoft.UI.Xaml.Media.SolidColorBrush(
            tracking.IsTracking
                ? (Windows.UI.Color)Application.Current.Resources["SuccessColor"]
                : (Windows.UI.Color)Application.Current.Resources["GoalBehindColor"]);
    }

    private void Nav_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string tag)
            NavigateTo(tag);
    }

    public void NavigateTo(string tag)
    {
        if (!_routes.TryGetValue(tag, out var pageType)) return;
        ContentFrame.Navigate(pageType);
        SetActiveNav(tag);
    }

    private void SetActiveNav(string tag)
    {
        foreach (var child in NavPanel.Children)
        {
            if (child is Button b)
                b.Style = (Style)Application.Current.Resources[
                    b.Tag as string == tag ? "NavButtonActiveStyle" : "NavButtonStyle"];
        }
    }
}
