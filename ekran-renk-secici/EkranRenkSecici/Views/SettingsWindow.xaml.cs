using System.Windows;
using EkranRenkSecici.ViewModels;

namespace EkranRenkSecici.Views;

public partial class SettingsWindow : Window
{
    public SettingsWindow()
    {
        InitializeComponent();
        var vm = new SettingsViewModel();
        vm.RequestClose += success =>
        {
            DialogResult = success;
            Close();
        };
        DataContext = vm;
    }
}
