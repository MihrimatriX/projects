using System;
using System.Threading;
using System.Windows.Input;

namespace ClipboardYoneticisi.Helpers
{
    public static class PasteSimulator
    {
        public static void SimulatePaste(int delayMs = 80)
        {
            Thread.Sleep(delayMs);

            var inputs = new Win32Api.INPUT[4];

            inputs[0] = KeyEvent(Win32Api.VK_CONTROL, false);
            inputs[1] = KeyEvent(Win32Api.VK_V, false);
            inputs[2] = KeyEvent(Win32Api.VK_V, true);
            inputs[3] = KeyEvent(Win32Api.VK_CONTROL, true);

            Win32Api.SendInput((uint)inputs.Length, inputs, System.Runtime.InteropServices.Marshal.SizeOf<Win32Api.INPUT>());
        }

        private static Win32Api.INPUT KeyEvent(ushort key, bool keyUp)
        {
            return new Win32Api.INPUT
            {
                type = Win32Api.INPUT_KEYBOARD,
                U = new Win32Api.InputUnion
                {
                    ki = new Win32Api.KEYBDINPUT
                    {
                        wVk = key,
                        dwFlags = keyUp ? Win32Api.KEYEVENTF_KEYUP : 0
                    }
                }
            };
        }
    }

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
                var token = part.Trim();
                switch (token.ToUpperInvariant())
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
                        if (!Enum.TryParse(token, ignoreCase: true, out Key parsedKey))
                            return false;
                        key = parsedKey;
                        break;
                }
            }

            return key != Key.None;
        }
    }
}
