using CommunityToolkit.Mvvm.ComponentModel;
using SistemYoneticisi.Modules;

namespace SistemYoneticisi.ViewModels;

public partial class ModuleNavItem : ObservableObject
{
    public string Id { get; }
    public string Title { get; }
    public string Icon { get; }
    public string NavLabel { get; }

    public ModuleNavItem(IMonitorModule module)
    {
        Id = module.Id;
        Title = module.Title;
        Icon = module.Icon;
        NavLabel = module.NavLabel;
    }

    [ObservableProperty]
    private bool _isActive;
}
