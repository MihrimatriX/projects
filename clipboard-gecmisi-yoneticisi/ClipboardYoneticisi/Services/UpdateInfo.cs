namespace ClipboardYoneticisi.Services
{
    public class UpdateInfo
    {
        public required Version LatestVersion { get; init; }
        public string ReleaseNotes { get; init; } = string.Empty;
        public string DownloadUrl { get; init; } = string.Empty;
    }

    public class UpdateManifest
    {
        public string? LatestVersion { get; set; }
        public string? ReleaseNotes { get; set; }
        public string? DownloadUrl { get; set; }
    }
}
