namespace SistemYoneticisi.ViewModels;

public sealed class ModuleCardItem
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Description { get; init; }
    public required string AccentBrushKey { get; init; }
    public required string ShortcutText { get; init; }
}
