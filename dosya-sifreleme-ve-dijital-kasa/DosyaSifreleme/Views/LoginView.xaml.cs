using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DosyaSifreleme.ViewModels;

namespace DosyaSifreleme.Views;

public partial class LoginView : UserControl
{
    private bool _syncingPassword;

    public LoginView()
    {
        InitializeComponent();
        // Açılışta/kilitten sonra doğrudan parola yazılabilsin (konum yoksa önce konum kutusu).
        Loaded += (_, _) =>
        {
            if (DataContext is LoginViewModel { VaultPath.Length: > 0 }) PasswordInput.Focus();
            else VaultPathInput.Focus();
        };
    }

    private void PasswordInput_PasswordChanged(object sender, RoutedEventArgs e)
    {
        if (_syncingPassword || DataContext is not LoginViewModel vm) return;
        vm.Password = PasswordInput.Password;
        vm.UpdatePasswordStrength(PasswordInput.Password);
        _syncingPassword = true;
        PasswordTextInput.Text = PasswordInput.Password;
        _syncingPassword = false;
    }

    private void PasswordTextInput_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (_syncingPassword || DataContext is not LoginViewModel vm) return;
        vm.Password = PasswordTextInput.Text;
        vm.UpdatePasswordStrength(PasswordTextInput.Text);
        _syncingPassword = true;
        PasswordInput.Password = PasswordTextInput.Text;
        _syncingPassword = false;
    }

    private void PasswordInput_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || DataContext is not LoginViewModel vm) return;
        if (vm.SubmitCommand.CanExecute(null))
            vm.SubmitCommand.Execute(null);
        e.Handled = true;
    }
}
