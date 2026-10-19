using System;
using System.Diagnostics;
using System.Linq;
using ClipboardYoneticisi.Helpers;

namespace ClipboardYoneticisi.Services
{
    public static class SensitiveAppGuard
    {
        public static bool ShouldIgnoreClipboard()
        {
            var settings = SettingsService.Instance.Settings;
            if (!settings.ExcludeSensitiveApps)
                return false;

            try
            {
                var hwnd = Win32Api.GetForegroundWindow();
                if (hwnd == IntPtr.Zero)
                    return false;

                Win32Api.GetWindowThreadProcessId(hwnd, out uint processId);
                if (processId == 0)
                    return false;

                using var process = Process.GetProcessById((int)processId);
                var name = process.ProcessName;

                return settings.ExcludedProcessNames.Any(excluded =>
                    name.Contains(excluded, StringComparison.OrdinalIgnoreCase));
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Sensitive app check failed: {ex.Message}");
                return false;
            }
        }
    }
}
