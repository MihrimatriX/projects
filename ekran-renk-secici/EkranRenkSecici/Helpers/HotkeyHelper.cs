using System;
using System.Linq;
using System.Windows.Input;

namespace EkranRenkSecici.Helpers;

public static class HotkeyHelper
{
    public static ModifierKeys ParseModifiers(string modifiersCsv)
    {
        var parts = modifiersCsv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        ModifierKeys result = ModifierKeys.None;

        foreach (var part in parts)
        {
            if (part.Equals("Control", StringComparison.OrdinalIgnoreCase))
            {
                result |= ModifierKeys.Control;
            }
            else if (part.Equals("Shift", StringComparison.OrdinalIgnoreCase))
            {
                result |= ModifierKeys.Shift;
            }
            else if (part.Equals("Alt", StringComparison.OrdinalIgnoreCase))
            {
                result |= ModifierKeys.Alt;
            }
            else if (part.Equals("Windows", StringComparison.OrdinalIgnoreCase))
            {
                result |= ModifierKeys.Windows;
            }
        }

        return result == ModifierKeys.None ? ModifierKeys.Control : result;
    }

    public static Key ParseKey(string keyName)
    {
        return Enum.TryParse<Key>(keyName, true, out var key) ? key : Key.C;
    }

    public static string FormatDisplay(string modifiersCsv, string key)
    {
        var labels = modifiersCsv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(m => m switch
            {
                "Control" => "Ctrl",
                "Shift" => "Shift",
                "Alt" => "Alt",
                "Windows" => "Win",
                _ => m
            });
        return string.Join("+", labels.Append(key.ToUpperInvariant()));
    }
}
