using System;
using System.Windows;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi
{
    public partial class AboutWindow : Window
    {
        public AboutWindow()
        {
            InitializeComponent();
            VersionText.Text = $"Sürüm {AppVersion.Display}";
        }

        private async void CheckUpdatesButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var info = await new UpdateCheckService().CheckForUpdatesAsync(force: true);
                if (info != null)
                    new UpdateWindow(info) { Owner = this }.ShowDialog();
                else
                {
                    MessageBox.Show(
                        "Güncel sürümü kullanıyorsunuz.",
                        "Güncelleme",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                LogService.Warning($"Update check failed: {ex.Message}");
                MessageBox.Show(
                    "Güncelleme kontrol edilemedi.",
                    "Güncelleme",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();
    }
}
