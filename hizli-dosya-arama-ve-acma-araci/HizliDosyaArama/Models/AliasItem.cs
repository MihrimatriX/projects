using CommunityToolkit.Mvvm.ComponentModel;

namespace HizliDosyaArama.Models;

public partial class AliasItem : ObservableObject
{
    public string Name { get; init; } = string.Empty;
    public string Query { get; init; } = string.Empty;

    [ObservableProperty]
    private bool _isActive;
}
