using System.Windows;
using SistemYoneticisi.Services;

namespace SistemYoneticisi;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();
        VersionText.Text = $"Sürüm {AppVersion.Version}";
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();
}
