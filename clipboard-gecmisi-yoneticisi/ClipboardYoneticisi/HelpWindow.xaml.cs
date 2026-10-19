using System.Windows;

namespace ClipboardYoneticisi
{
    public partial class HelpWindow : Window
    {
        public HelpWindow()
        {
            InitializeComponent();
            // Kisayollar ayarlardan degistirilebilir; sabit metin yaniltiyordu.
            var settings = Services.SettingsService.Instance.Settings;
            ShowHotkeyRun.Text = settings.ShowHotkey;
            StackHotkeyRun.Text = settings.StackHotkey;
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();
    }
}
