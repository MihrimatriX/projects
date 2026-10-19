using EkranZamani_WinUI.Services;
using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI;

public sealed partial class SettingsPage : Page
{
    public SettingsPageViewModel ViewModel { get; } = new();

    public SettingsPage()
    {
        InitializeComponent();
        DataContext = ViewModel;
    }

    private void Save_Click(object sender, RoutedEventArgs e) =>
        ViewModel.SaveCommand.Execute(null);

    private async void DeleteData_Click(object sender, RoutedEventArgs e)
    {
        var confirmBox = new TextBox { PlaceholderText = "SİL yazın" };
        var dlg = new ContentDialog
        {
            Title = "Yerel veriler silinsin mi?",
            Content = new StackPanel
            {
                Spacing = 12,
                Children =
                {
                    new TextBlock
                    {
                        Text = "Bu işlem günlük kayıtları, kategori kurallarını ve odak hedeflerini bu cihazdan kaldırır. Geri alınamaz.",
                        TextWrapping = TextWrapping.Wrap
                    },
                    confirmBox
                }
            },
            PrimaryButtonText = "Kalıcı olarak sil",
            CloseButtonText = "Vazgeç",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot
        };

        dlg.PrimaryButtonClick += (_, args) =>
        {
            if (!string.Equals(confirmBox.Text.Trim(), "SİL", StringComparison.Ordinal))
                args.Cancel = true;
        };

        if (await dlg.ShowAsync() == ContentDialogResult.Primary)
            ViewModel.DeleteAllDataCommand.Execute(null);
    }
}
