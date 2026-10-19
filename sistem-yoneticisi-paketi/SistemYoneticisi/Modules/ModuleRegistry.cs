using CommunityToolkit.Mvvm.ComponentModel;
using SistemYoneticisi.ViewModels;

namespace SistemYoneticisi.Modules;

public sealed class ModuleRegistry
{
    private readonly Dictionary<string, IMonitorModule> _modules = new(StringComparer.OrdinalIgnoreCase);

    public IReadOnlyList<IMonitorModule> Modules { get; private set; } = [];

    public void Register(params IMonitorModule[] modules)
    {
        foreach (var module in modules)
            _modules[module.Id] = module;

        Modules = _modules.Values.OrderBy(m => m.Order).ToList();
    }

    public bool TryGet(string id, out IMonitorModule module) => _modules.TryGetValue(id, out module!);

    public ObservableObject CreateViewModel(string id, MainViewModel host)
    {
        if (!_modules.TryGetValue(id, out var module))
            throw new KeyNotFoundException($"Modül bulunamadı: {id}");
        return module.CreateViewModel(host);
    }
}
