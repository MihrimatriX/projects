using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class WeeklyPage : Page
{
    public WeeklyPageViewModel ViewModel { get; } = new();

    public WeeklyPage()
    {
        InitializeComponent();
        DataContext = ViewModel;
    }
}
