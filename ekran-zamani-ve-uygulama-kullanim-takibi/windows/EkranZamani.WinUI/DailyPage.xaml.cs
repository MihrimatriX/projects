using EkranZamani_WinUI.Services;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class DailyPage : Page
{
    public DailyPage()
    {
        InitializeComponent();
        DataContext = AppNavigation.DailyViewModel;
    }
}
