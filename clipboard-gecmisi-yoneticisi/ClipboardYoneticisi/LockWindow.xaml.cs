using System.Windows;
using System.Windows.Input;

namespace ClipboardYoneticisi
{
    public partial class LockWindow : Window
    {
        public string? EnteredPassword { get; private set; }

        public LockWindow(bool isSetup)
        {
            InitializeComponent();
            TitleText.Text = isSetup
                ? "Şifreli mod — parola belirleyin"
                : "Oturum kilidi — parolanızı girin";
            PasswordBox.Focus();
        }

        private void UnlockButton_Click(object sender, RoutedEventArgs e)
        {
            EnteredPassword = PasswordBox.Password;
            if (string.IsNullOrWhiteSpace(EnteredPassword))
            {
                MessageBox.Show("Parola boş olamaz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            DialogResult = true;
            Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void PasswordBox_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
                UnlockButton_Click(sender, e);
        }
    }
}
