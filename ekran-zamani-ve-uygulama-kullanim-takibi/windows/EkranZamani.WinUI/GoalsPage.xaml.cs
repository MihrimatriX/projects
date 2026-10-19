using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class GoalsPage : Page
{
    public GoalsPageViewModel ViewModel { get; } = new();

    public GoalsPage()
    {
        InitializeComponent();
        DataContext = ViewModel;
    }

    private void ScrollToForm_Click(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) =>
        GoalForm.StartBringIntoView();
}
