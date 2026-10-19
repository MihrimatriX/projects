using System;
using System.Diagnostics;
using InputSimulatorStandard;
using InputSimulatorStandard.Native;
using OtomasyonMakro.Helpers;

namespace OtomasyonMakro.Services
{
    /// <summary>
    /// Oynatmanın masaüstüne dokunduğu tek yer. Testler sahte bir uygulama verir;
    /// böylece hiçbir test kullanıcının masaüstüne gerçek fare/klavye girdisi göndermez.
    /// </summary>
    public interface IMacroInput
    {
        void MoveCursor(int x, int y);
        void LeftClick();
        void TypeText(string text);
        void PressKey(VirtualKeyCode key);
        void ClickUiElement(string? name, string? automationId, string? className);
        string GetForegroundWindowTitle();

        /// <summary>Odaklı pencerenin süreç adı; odaklı pencere yoksa null, ad çözülemezse "".</summary>
        string? GetForegroundProcessName();
    }

    public sealed class DesktopInput : IMacroInput, IDisposable
    {
        private readonly InputSimulator _inputSimulator = new();
        private readonly UIAutomationService _uiAutomation = new();

        public void MoveCursor(int x, int y) => Win32Api.SetCursorPos(x, y);

        public void LeftClick() =>
            Win32Api.mouse_event(Win32Api.MOUSEEVENTF_LEFTDOWN | Win32Api.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);

        public void TypeText(string text) => _inputSimulator.Keyboard.TextEntry(text);

        public void PressKey(VirtualKeyCode key) => _inputSimulator.Keyboard.KeyPress(key);

        public void ClickUiElement(string? name, string? automationId, string? className) =>
            _uiAutomation.ClickElement(name, automationId, className);

        public string GetForegroundWindowTitle() => WindowInfoService.GetForegroundWindowTitle();

        public string? GetForegroundProcessName()
        {
            IntPtr hwnd = Win32Api.GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;

            Win32Api.GetWindowThreadProcessId(hwnd, out uint pid);
            if (pid == 0) return string.Empty;
            try
            {
                using var proc = Process.GetProcessById((int)pid);
                return proc.ProcessName;
            }
            catch
            {
                return string.Empty;
            }
        }

        public void Dispose() => _uiAutomation.Dispose();
    }
}
