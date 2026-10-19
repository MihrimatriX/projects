using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace SistemYoneticisi.ViewModels;

public partial class HomeViewModel : ObservableObject
{
    public DashboardViewModel Metrics { get; }
    public ObservableCollection<ModuleCardItem> Modules { get; } = new();

    private readonly MainViewModel _host;

    public HomeViewModel(MainViewModel host, DashboardViewModel metrics)
    {
        _host = host;
        Metrics = metrics;

        foreach (var module in host.ModuleRegistry.Modules.Where(m => m.Id != "Home"))
        {
            Modules.Add(new ModuleCardItem
            {
                Id = module.Id,
                Title = module.Title,
                Description = ModuleDescriptions.Get(module.Id),
                AccentBrushKey = ModuleDescriptions.AccentBrush(module.Id),
                ShortcutText = module.ShortcutDigit is { } d ? d : "—"
            });
        }
    }

    [RelayCommand]
    private void OpenModule(string moduleId) => _host.NavigateCommand.Execute(moduleId);

    [RelayCommand]
    private void OpenDashboard() => _host.NavigateCommand.Execute("Dashboard");
}

internal static class ModuleDescriptions
{
    private static readonly Dictionary<string, string> Text = new()
    {
        ["Dashboard"] = "Metrik kartları, sparkline geçmişi ve alarm özeti.",
        ["Processes"] = "Sıralanabilir tablo, arama ve sonlandırma onayı.",
        ["Services"] = "Windows servis listesi; başlat/durdur.",
        ["Startup"] = "Registry ve klasör girişleri.",
        ["Network"] = "Bağlantı tablosu ve filtreleme."
    };

    public static string Get(string id) => Text.TryGetValue(id, out var t) ? t : string.Empty;

    public static string AccentBrush(string id) => id switch
    {
        "Dashboard" => "AccentCpuBrush",
        "Processes" => "AccentRamBrush",
        "Services" => "AccentDiskBrush",
        "Startup" => "AccentNetBrush",
        "Network" => "AccentNetBrush",
        _ => "AccentBrush"
    };
}
