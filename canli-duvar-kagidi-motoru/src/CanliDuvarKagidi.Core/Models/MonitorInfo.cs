namespace CanliDuvarKagidi.Core.Models;

public sealed class MonitorInfo
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required int X { get; init; }
    public required int Y { get; init; }
    public required int Width { get; init; }
    public required int Height { get; init; }
    public required bool IsPrimary { get; init; }
}
