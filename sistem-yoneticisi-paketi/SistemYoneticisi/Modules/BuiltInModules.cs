using SistemYoneticisi.ViewModels;

namespace SistemYoneticisi.Modules;

internal sealed class HomeModule : MonitorModuleBase
{
    public override string Id => "Home";
    public override string Title => "Ana Sayfa";
    public override string Icon => "⌂";
    public override int Order => 0;
    public override string? ShortcutDigit => null;
    public override string StatusMessage => "Ana sayfa";

    public override HomeViewModel CreateViewModel(MainViewModel host) => host.HomeVM;
}

internal sealed class DashboardModule : MonitorModuleBase
{
    public override string Id => "Dashboard";
    public override string Title => "Dashboard";
    public override string Icon => "▣";
    public override int Order => 1;
    public override string? ShortcutDigit => "1";
    public override string StatusMessage => "Dashboard";

    public override DashboardViewModel CreateViewModel(MainViewModel host) => host.DashboardVM;
}

internal sealed class ProcessesModule : MonitorModuleBase
{
    public override string Id => "Processes";
    public override string Title => "Süreçler";
    public override string Icon => "☰";
    public override int Order => 2;
    public override string? ShortcutDigit => "2";
    public override string StatusMessage => "Süreçler";

    public override ProcessViewModel CreateViewModel(MainViewModel host) => host.ProcessVM;

    public override void OnNavigate(MainViewModel host) =>
        host.ProcessVM.RefreshCommand.Execute(null);
}

internal sealed class ServicesModule : MonitorModuleBase
{
    public override string Id => "Services";
    public override string Title => "Servisler";
    public override string Icon => "⚙";
    public override int Order => 3;
    public override string? ShortcutDigit => "3";
    public override string StatusMessage => "Servisler";

    public override ServicesViewModel CreateViewModel(MainViewModel host) => host.ServicesVM;

    public override void OnNavigate(MainViewModel host) =>
        host.ServicesVM.RefreshCommand.Execute(null);
}

internal sealed class StartupModule : MonitorModuleBase
{
    public override string Id => "Startup";
    public override string Title => "Başlangıç";
    public override string Icon => "⚡";
    public override int Order => 4;
    public override string? ShortcutDigit => "4";
    public override string StatusMessage => "Başlangıç";

    public override StartupViewModel CreateViewModel(MainViewModel host) => host.StartupVM;

    public override void OnNavigate(MainViewModel host) =>
        host.StartupVM.RefreshCommand.Execute(null);
}

internal sealed class NetworkModule : MonitorModuleBase
{
    public override string Id => "Network";
    public override string Title => "Ağ";
    public override string Icon => "◎";
    public override int Order => 5;
    public override string? ShortcutDigit => "5";
    public override string StatusMessage => "Ağ";

    public override NetworkViewModel CreateViewModel(MainViewModel host) => host.NetworkVM;

    public override void OnNavigate(MainViewModel host) =>
        host.NetworkVM.RefreshCommand.Execute(null);
}

public static class BuiltInModules
{
    public static void RegisterAll(ModuleRegistry registry)
    {
        registry.Register(
            new HomeModule(),
            new DashboardModule(),
            new ProcessesModule(),
            new ServicesModule(),
            new StartupModule(),
            new NetworkModule());
    }
}
