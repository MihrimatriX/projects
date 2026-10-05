using System.IO;
using System.Net.Http;
using System.Text.Json;

namespace ClipboardYoneticisi.Services
{
    public class UpdateCheckService
    {
        private static readonly HttpClient HttpClient = new()
        {
            Timeout = TimeSpan.FromSeconds(12)
        };

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        public async Task<UpdateInfo?> CheckForUpdatesAsync(bool force = false)
        {
            var settings = SettingsService.Instance.Settings;
            // Otomatik kontrol kapaliyken elle "Guncellemeleri kontrol et" yine calismali.
            if (!force && !settings.CheckForUpdates)
                return null;

            if (!force &&
                settings.LastUpdateCheckUtc.HasValue &&
                DateTime.UtcNow - settings.LastUpdateCheckUtc.Value < TimeSpan.FromHours(24))
            {
                return null;
            }

            UpdateInfo? candidate = null;

            var localPath = Path.Combine(AppContext.BaseDirectory, "version.json");
            if (File.Exists(localPath))
                candidate = PickNewer(candidate, ParseManifest(await File.ReadAllTextAsync(localPath)));

            if (!string.IsNullOrWhiteSpace(settings.UpdateFeedUrl))
            {
                try
                {
                    var remoteJson = await HttpClient.GetStringAsync(settings.UpdateFeedUrl);
                    candidate = PickNewer(candidate, ParseManifest(remoteJson));
                }
                catch (Exception ex)
                {
                    LogService.Warning($"Update feed fetch failed: {ex.Message}");
                }
            }

            settings.LastUpdateCheckUtc = DateTime.UtcNow;
            SettingsService.Instance.Save();

            if (candidate != null && candidate.LatestVersion > AppVersion.Current)
                return candidate;

            return null;
        }

        internal static UpdateInfo? ParseManifest(string json)
        {
            try
            {
                var manifest = JsonSerializer.Deserialize<UpdateManifest>(json, JsonOptions);
                if (manifest?.LatestVersion == null || !Version.TryParse(manifest.LatestVersion, out var version))
                    return null;

                return new UpdateInfo
                {
                    LatestVersion = version,
                    ReleaseNotes = manifest.ReleaseNotes ?? string.Empty,
                    DownloadUrl = manifest.DownloadUrl ?? string.Empty
                };
            }
            catch (JsonException)
            {
                return null;
            }
        }

        private static UpdateInfo? PickNewer(UpdateInfo? current, UpdateInfo? next)
        {
            if (next == null)
                return current;

            if (current == null)
                return next;

            return next.LatestVersion > current.LatestVersion ? next : current;
        }
    }
}
