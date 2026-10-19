namespace OtomasyonMakro.Models
{
    public sealed class HotkeyAssignment
    {
        public string Key { get; init; } = "";
        public string MacroName { get; init; } = "";
        public string Action { get; init; } = "";
        public bool HasConflict { get; init; }
        public string? ConflictWith { get; init; }
    }
}
