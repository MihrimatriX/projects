using CommunityToolkit.Mvvm.ComponentModel;
using SistemYoneticisi.ViewModels;

namespace SistemYoneticisi.Modules;

public abstract class MonitorModuleBase : IMonitorModule
{
    public abstract string Id { get; }
    public abstract string Title { get; }
    public abstract string Icon { get; }
    public abstract int Order { get; }
    public abstract string? ShortcutDigit { get; }
    public abstract string StatusMessage { get; }

    public string NavLabel => Title;

    public abstract ObservableObject CreateViewModel(MainViewModel host);

    public virtual void OnNavigate(MainViewModel host) { }
}
