using Microsoft.Win32;

namespace CanliDuvarKagidi_Shell.Services;

public static class StartupService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "CanliDuvarKagidi";

    public static void SetRunAtStartup(bool enabled)
    {
        if (AppServices.UiTestMode)
            return; // testler kullanicinin Run anahtarina dokunmaz

        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
            ?? throw new InvalidOperationException("Baslangic anahtari acilamadi.");

        if (enabled)
        {
            var exePath = Environment.ProcessPath
                ?? throw new InvalidOperationException("Uygulama yolu bulunamadi.");
            key.SetValue(AppName, $"\"{exePath}\"");
        }
        else
        {
            key.DeleteValue(AppName, throwOnMissingValue: false);
        }
    }

    public static bool IsRunAtStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
        return key?.GetValue(AppName) != null;
    }
}
