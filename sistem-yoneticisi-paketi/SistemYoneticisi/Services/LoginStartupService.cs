using Microsoft.Win32;

namespace SistemYoneticisi.Services;

public static class LoginStartupService
{
    // Oturum açılışında başlatma: HKCU\...\Run altına exe yolunu yazar (yönetici gerekmez).
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "SistemYoneticisiPaketi";

    public static bool IsEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
            return key?.GetValue(ValueName) != null;
        }
        catch (Exception ex)
        {
            LogService.Error("Login startup check failed", ex);
            return false;
        }
    }

    public static bool SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
            if (key == null) return false;

            if (enabled)
            {
                var exe = Environment.ProcessPath;
                if (string.IsNullOrEmpty(exe)) return false;
                key.SetValue(ValueName, $"\"{exe}\"");
            }
            else
            {
                key.DeleteValue(ValueName, false);
            }

            return true;
        }
        catch (Exception ex)
        {
            LogService.Error("Login startup toggle failed", ex);
            return false;
        }
    }
}
