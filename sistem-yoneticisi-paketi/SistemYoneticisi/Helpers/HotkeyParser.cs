using System.Windows.Input;

namespace SistemYoneticisi.Helpers;

public static class HotkeyParser
{
    public static bool TryParse(string hotkey, out Key key, out ModifierKeys modifiers)
    {
        key = Key.None;
        modifiers = ModifierKeys.None;

        if (string.IsNullOrWhiteSpace(hotkey))
            return false;

        foreach (var part in hotkey.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            switch (part.Trim().ToUpperInvariant())
            {
                case "CTRL":
                case "CONTROL":
                    modifiers |= ModifierKeys.Control;
                    break;
                case "ALT":
                    modifiers |= ModifierKeys.Alt;
                    break;
                case "SHIFT":
                    modifiers |= ModifierKeys.Shift;
                    break;
                case "WIN":
                case "WINDOWS":
                    modifiers |= ModifierKeys.Windows;
                    break;
                default:
                    if (!Enum.TryParse(part, ignoreCase: true, out Key parsedKey))
                        return false;
                    key = parsedKey;
                    break;
            }
        }

        return key != Key.None;
    }
}
