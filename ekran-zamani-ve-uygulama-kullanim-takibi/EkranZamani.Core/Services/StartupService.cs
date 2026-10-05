using System;
using System.IO;
using Microsoft.Win32;

namespace EkranZamani.Services
{
    public static class StartupService
    {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppName = "EkranZamani";

        public static bool IsEnabled()
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
            return key?.GetValue(AppName) is string;
        }

        public static void SetEnabled(bool enabled)
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true)
                ?? Registry.CurrentUser.CreateSubKey(RunKeyPath, true);

            if (enabled)
            {
                var exePath = Environment.ProcessPath;
                if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
                    exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;

                if (string.IsNullOrEmpty(exePath))
                    throw new InvalidOperationException("Uygulama yolu bulunamadı.");

                key.SetValue(AppName, $"\"{exePath}\"");
            }
            else
            {
                key.DeleteValue(AppName, false);
            }
        }
    }
}
