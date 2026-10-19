using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Security.Principal;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SistemYoneticisi.Modules;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels;

public partial class MainViewModel : ObservableObject, IDisposable
{
    [ObservableProperty]
    private ObservableObject? _currentViewModel;

    [ObservableProperty]
    private string _activeSection = "Home";

    [ObservableProperty]
    private string _statusMessage = "Hazır";

    [ObservableProperty]
    private bool _isElevated;

    [ObservableProperty]
    private string _trayTooltip = "Sistem Yöneticisi Paketi";

    public ModuleRegistry ModuleRegistry { get; } = new();
    public GlobalHotkeyService GlobalHotkeyService { get; } = new();

    [ObservableProperty]
    private string _hotkeyStatusText = string.Empty;

    public ObservableCollection<ModuleNavItem> NavigationItems { get; } = new();

    public string VersionDisplay => AppVersion.Version;

    public SystemInfoService SystemInfoService { get; }
    public ProcessService ProcessService { get; }
    public StartupService StartupService { get; }
    public ServiceManagerService ServiceManagerService { get; }
    public NetworkConnectionService NetworkConnectionService { get; }
    public MetricsHistoryService HistoryService { get; }
    public AlarmService AlarmService { get; }

    public DashboardViewModel DashboardVM { get; }
    public HomeViewModel HomeVM { get; }
    // Liste modülleri ilk açıldıklarında oluşturulur: hepsini açılışta yüklemek (WMI servis sorgusu, tüm süreçlerin
    // modül bilgisi) pencerenin saniyelerce gecikmesine ve arka planda gereksiz 3 sn süreç taramasına yol açıyordu.
    private ProcessViewModel? _processVm;
    private ServicesViewModel? _servicesVm;
    private StartupViewModel? _startupVm;
    private NetworkViewModel? _networkVm;
    public ProcessViewModel ProcessVM => _processVm ??= new ProcessViewModel(ProcessService, this);
    public ServicesViewModel ServicesVM => _servicesVm ??= new ServicesViewModel(ServiceManagerService, this);
    public StartupViewModel StartupVM => _startupVm ??= new StartupViewModel(StartupService, this);
    public NetworkViewModel NetworkVM => _networkVm ??= new NetworkViewModel(NetworkConnectionService, this);

    public MainViewModel()
    {
        AppPaths.EnsureDirectories();
        ThemeService.ApplyHighContrast(SettingsService.Instance.Settings.HighContrastMode);

        IsElevated = new WindowsPrincipal(WindowsIdentity.GetCurrent())
            .IsInRole(WindowsBuiltInRole.Administrator);

        SystemInfoService = new SystemInfoService();
        ProcessService = new ProcessService();
        StartupService = new StartupService();
        ServiceManagerService = new ServiceManagerService();
        NetworkConnectionService = new NetworkConnectionService();
        HistoryService = new MetricsHistoryService();
        AlarmService = new AlarmService();

        DashboardVM = new DashboardViewModel(SystemInfoService, this, HistoryService, AlarmService, ProcessService);
        // HomeViewModel modul kartlarini yapicida doldurur; once kayit yapilmazsa liste bos kalir.
        BuiltInModules.RegisterAll(ModuleRegistry);
        HomeVM = new HomeViewModel(this, DashboardVM);

        foreach (var module in ModuleRegistry.Modules)
            NavigationItems.Add(new ModuleNavItem(module));
        NavigationItems.First(n => n.Id == ActiveSection).IsActive = true;

        RegisterHotkeys();

        DashboardVM.MetricsUpdated += (cpu, ram) =>
            TrayTooltip = $"CPU {cpu:F0}% · RAM {ram:F0}%";

        AlarmService.AlarmTriggered += (title, message) =>
            RequestTrayNotification?.Invoke(title, message);

        CurrentViewModel = HomeVM;
        StatusMessage = IsElevated
            ? "Yönetici modu aktif • 1–5 ile modüllere geçin"
            : "Standart mod — servis/süreç işlemleri için yönetici gerekebilir";

        LogService.Info("MainViewModel initialized.");
    }

    [RelayCommand]
    private void Navigate(string destination)
    {
        RequestShowWindow?.Invoke();

        if (!ModuleRegistry.TryGet(destination, out var module))
            return;

        CurrentViewModel = module.CreateViewModel(this);
        ActiveSection = module.Id;
        StatusMessage = module.StatusMessage;
        module.OnNavigate(this);
    }

    partial void OnActiveSectionChanged(string value)
    {
        foreach (var item in NavigationItems)
            item.IsActive = item.Id == value;
    }

    public void RegisterHotkeys()
    {
        var settings = SettingsService.Instance.Settings;
        var ok = GlobalHotkeyService.Register(settings);
        HotkeyStatusText = ok || !settings.GlobalHotkeyEnabled
            ? string.Empty
            : "Global kısayol kaydı başarısız — ayarları kontrol edin";
        OnPropertyChanged(nameof(ShowHotkeyWarning));
    }

    public bool ShowHotkeyWarning => !string.IsNullOrEmpty(HotkeyStatusText);

    [RelayCommand]
    private void ShowSettings() => RequestSettings?.Invoke();

    [RelayCommand]
    private void ShowAbout() => RequestAbout?.Invoke();

    [RelayCommand]
    private void ShowHelp() => RequestHelp?.Invoke();

    public void OnSettingsSaved()
    {
        ThemeService.ApplyHighContrast(SettingsService.Instance.Settings.HighContrastMode);
        DashboardVM.UpdateHistoryStatus();
        LoginStartupService.SetEnabled(SettingsService.Instance.Settings.RunAtLogin);
        RegisterHotkeys();
        StatusMessage = "Ayarlar kaydedildi";
    }

    public event Action? RequestShowWindow;
    public event Action? RequestSettings;
    public event Action? RequestAbout;
    public event Action? RequestHelp;
    public event Action<string, string>? RequestTrayNotification;

    public void Dispose()
    {
        GlobalHotkeyService.Dispose();
        HistoryService.Dispose();
        LogService.Info("MainViewModel disposed.");
    }
}
