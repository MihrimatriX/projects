using CommunityToolkit.Mvvm.ComponentModel;
using SistemYoneticisi.ViewModels;

namespace SistemYoneticisi.Modules;

public interface IMonitorModule
{
    string Id { get; }
    string Title { get; }
    string Icon { get; }
    int Order { get; }
    string? ShortcutDigit { get; }

    ObservableObject CreateViewModel(MainViewModel host);
    void OnNavigate(MainViewModel host);
    string StatusMessage { get; }
    string NavLabel { get; }
}
