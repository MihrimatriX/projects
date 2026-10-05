using System.IO;
using ClipboardYoneticisi.Services;
using Xunit;

namespace ClipboardYoneticisi.Tests;

public class UpdateCheckServiceTests
{
    [Fact]
    public void ParseManifest_reads_version_and_notes()
    {
        const string json = """
            {
              "latestVersion": "1.2.0",
              "releaseNotes": "Test notes",
              "downloadUrl": "https://example.com/dl"
            }
            """;

        var info = UpdateCheckService.ParseManifest(json);

        Assert.NotNull(info);
        Assert.Equal(new Version(1, 2, 0), info!.LatestVersion);
        Assert.Equal("Test notes", info.ReleaseNotes);
        Assert.Equal("https://example.com/dl", info.DownloadUrl);
    }

    [Fact]
    public void ParseManifest_returns_null_for_invalid_json()
    {
        Assert.Null(UpdateCheckService.ParseManifest("{ invalid"));
        Assert.Null(UpdateCheckService.ParseManifest("""{"latestVersion":"x.y"}"""));
    }

    [Fact]
    public void AppVersion_display_matches_semver_parts()
    {
        var display = AppVersion.Display;
        Assert.Matches(@"^\d+\.\d+\.\d+$", display);
    }
}
