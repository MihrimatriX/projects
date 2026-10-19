using EkranZamani.Models;

namespace EkranZamani.Services
{
    public static class SettingsApplier
    {
        public static void ApplySavedSettings(AppSettings settings)
        {
            AppServices.ApplyTheme?.Invoke(settings.Theme);
            try { StartupService.SetEnabled(settings.RunAtStartup); }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Startup: {ex.Message}"); }
            AppServices.Categories.Refresh();
            AppServices.RestartBridge();
            AppServices.RestartSyncApi();
        }
    }
}
