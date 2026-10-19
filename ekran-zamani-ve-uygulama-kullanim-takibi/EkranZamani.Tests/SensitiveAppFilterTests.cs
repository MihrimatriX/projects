using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class SensitiveAppFilterTests
{
    [Fact]
    public void ShouldSkipLogging_honors_user_blacklist()
    {
        var list = new List<string> { "spotify.exe" };
        Assert.True(SensitiveAppFilter.ShouldSkipLogging("Spotify.exe", list));
        Assert.False(SensitiveAppFilter.ShouldSkipLogging("Code.exe", list));
    }

    [Theory]
    [InlineData("slack.exe", true)]
    [InlineData("", false)]
    [InlineData("a", false)]
    public void IsValidBlacklistEntry_checks_shape(string entry, bool expected) =>
        Assert.Equal(expected, SensitiveAppFilter.IsValidBlacklistEntry(entry));
}
