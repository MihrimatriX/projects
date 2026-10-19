using CommunityToolkit.Mvvm.ComponentModel;
using DosyaSifreleme.Services;

namespace DosyaSifreleme.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty] private ObservableObject? _currentViewModel;

    public CryptographyService CryptographyService { get; } = new();
    public VaultService VaultService { get; }
    public AppSettings Settings { get; } = AppSettings.Load();
    public LoginViewModel LoginVM { get; }

    private DashboardViewModel? _dashboard;

    public MainViewModel()
    {
        VaultService = new VaultService(CryptographyService);
        LoginVM = new LoginViewModel(this, VaultService);
        CurrentViewModel = LoginVM;
    }

    public void NavigateToDashboard()
    {
        LoginVM.Password = string.Empty; // parola kasa açıkken bellekte tutulmaz; anahtar VaultService'te
        Settings.LastVaultPath = VaultService.ActiveVaultPath ?? string.Empty;
        Settings.Save();
        _dashboard = new DashboardViewModel(this, VaultService);
        CurrentViewModel = _dashboard;
    }

    public void NavigateToLogin()
    {
        VaultService.CloseVault();
        LoginVM.Password = string.Empty;
        LoginVM.UpdatePasswordStrength(string.Empty);
        LoginVM.IsCreatingNew = false; // kilitten sonra aynı kasayı açma ekranı
        CurrentViewModel = LoginVM;
        _dashboard = null;
    }

    public DashboardViewModel? ActiveDashboard => _dashboard;
}
