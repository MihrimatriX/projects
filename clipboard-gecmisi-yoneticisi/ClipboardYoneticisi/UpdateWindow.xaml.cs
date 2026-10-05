using System.Diagnostics;
using System.Windows;
using ClipboardYoneticisi.Services;

namespace ClipboardYoneticisi
{
    public partial class UpdateWindow : Window
    {
        private readonly UpdateInfo _update;

        public UpdateWindow(UpdateInfo update)
        {
            InitializeComponent();
            _update = update;
            VersionLine.Text = $"Mevcut: {AppVersion.Display}  →  Yeni: {_update.LatestVersion}";
            ReleaseNotesText.Text = string.IsNullOrWhiteSpace(_update.ReleaseNotes)
                ? "Sürüm notları paylaşılmadı."
                : _update.ReleaseNotes;
        }

        private void DownloadButton_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(_update.DownloadUrl))
            {
                Process.Start(new ProcessStartInfo(_update.DownloadUrl) { UseShellExecute = true });
            }
            Close();
        }

        private void LaterButton_Click(object sender, RoutedEventArgs e) => Close();
    }
}
