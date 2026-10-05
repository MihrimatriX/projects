using System.IO;
using System.Text.RegularExpressions;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DosyaSifreleme.Services;
using Microsoft.Win32;

namespace DosyaSifreleme.ViewModels;

public partial class LoginViewModel : ObservableObject
{
    private readonly MainViewModel _main;
    private readonly VaultService _vault;

    [ObservableProperty] private string _vaultPath = string.Empty;
    [ObservableProperty] private string _password = string.Empty;
    [ObservableProperty] private string _errorMessage = string.Empty;
    [ObservableProperty] private int _passwordStrengthScore;
    [ObservableProperty] private string _passwordStrengthLabel = "En az 12 karakter önerilir";
    [ObservableProperty] private bool _isCreatingNew;
    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private bool _isPasswordVisible;
    // Kilitlenme nedeni gibi bilgi satırı (hata değil).
    [ObservableProperty] private string _infoMessage = string.Empty;

    public string VaultDisplayName =>
        string.IsNullOrWhiteSpace(VaultPath)
            ? (IsCreatingNew ? "Yeni Kasa" : "Kişisel Kasa")
            : Path.GetFileName(VaultPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));

    public LoginViewModel(MainViewModel main, VaultService vault)
    {
        _main = main;
        _vault = vault;
        // Son açılan kasa hatırlanır; yoksa ilk açılış "yeni kasa" modunda başlar.
        VaultPath = main.Settings.LastVaultPath;
        IsCreatingNew = !File.Exists(Path.Combine(VaultPath, "vault.db"));
    }

    partial void OnVaultPathChanged(string value) => OnPropertyChanged(nameof(VaultDisplayName));
    partial void OnIsCreatingNewChanged(bool value) => OnPropertyChanged(nameof(VaultDisplayName));

    [RelayCommand]
    private void SelectFolder()
    {
        var dialog = new OpenFolderDialog
        {
            Title = IsCreatingNew ? "Yeni Kasa Klasörü Seçin" : "Mevcut Kasa Klasörünü Seçin"
        };
        if (dialog.ShowDialog(App.Owner) == true)
            VaultPath = dialog.FolderName;
    }

    [RelayCommand]
    private void ToggleMode()
    {
        IsCreatingNew = !IsCreatingNew;
        ErrorMessage = string.Empty;
        // Parola burada temizlenmez: PasswordBox bağlı değil, temizlenirse kutudaki parola ile VM ayrışır.
    }

    [RelayCommand]
    private void TogglePasswordVisibility() => IsPasswordVisible = !IsPasswordVisible;

    public void UpdatePasswordStrength(string password)
    {
        PasswordStrengthScore = ScorePassword(password);
        PasswordStrengthLabel = PasswordStrengthScore switch
        {
            0 => "En az 12 karakter önerilir",
            1 => "Zayıf · En az 12 karakter önerilir",
            2 => "Orta · En az 12 karakter önerilir",
            3 => "Güçlü · En az 12 karakter önerilir",
            _ => "Çok güçlü · En az 12 karakter önerilir"
        };
    }

    private static int ScorePassword(string val)
    {
        if (string.IsNullOrEmpty(val)) return 0;
        var score = 0;
        if (val.Length >= 8) score++;
        if (val.Length >= 12) score++;
        if (Regex.IsMatch(val, "[A-Z]") && Regex.IsMatch(val, "[a-z]")) score++;
        if (Regex.IsMatch(val, "[0-9]") && Regex.IsMatch(val, @"[^A-Za-z0-9]")) score++;
        return Math.Min(4, score);
    }

    [RelayCommand]
    private async Task SubmitAsync()
    {
        ErrorMessage = string.Empty;
        InfoMessage = string.Empty;
        VaultPath = VaultPath.Trim().Trim('"');

        if (string.IsNullOrWhiteSpace(VaultPath))
        {
            ErrorMessage = "Lütfen bir kasa klasörü seçin.";
            return;
        }

        if (!Path.IsPathFullyQualified(VaultPath))
        {
            ErrorMessage = "Kasa konumu tam bir klasör yolu olmalıdır (ör. D:\\Kasam).";
            return;
        }

        if (string.IsNullOrEmpty(Password) || Password.Length < 6)
        {
            ErrorMessage = "Parola en az 6 karakter olmalıdır.";
            return;
        }

        IsLoading = true;
        try
        {
            await Task.Run(() =>
            {
                if (IsCreatingNew)
                {
                    if (File.Exists(Path.Combine(VaultPath, "vault.db")))
                        throw new InvalidOperationException("Bu klasörde zaten bir kasa bulunuyor.");
                    _vault.CreateVault(VaultPath, Password);
                }
                else
                {
                    if (!File.Exists(Path.Combine(VaultPath, "vault.db")))
                        throw new InvalidOperationException("Seçilen klasörde geçerli bir kasa bulunamadı.");
                    if (!_vault.OpenVault(VaultPath, Password))
                        throw new InvalidOperationException("Geçersiz parola veya bozuk kasa dosyası.");
                }
            });

            _main.NavigateToDashboard();
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }
}
