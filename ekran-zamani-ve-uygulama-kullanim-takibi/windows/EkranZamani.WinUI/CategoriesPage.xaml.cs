using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class CategoriesPage : Page
{
    public CategoriesPageViewModel ViewModel { get; } = new();

    public CategoriesPage()
    {
        InitializeComponent();
        DataContext = ViewModel;
    }

    private void Category_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        // İlk bağlamada da SelectionChanged gelir (RemovedItems boş); onu işlemek Reload → yeni ComboBox → tekrar tetikleme döngüsü yaratır.
        if (e.RemovedItems.Count == 0) return;
        if (sender is ComboBox { DataContext: CategoryRuleItem row })
            ViewModel.UpdateCategoryCommand.Execute(row);
    }
}
