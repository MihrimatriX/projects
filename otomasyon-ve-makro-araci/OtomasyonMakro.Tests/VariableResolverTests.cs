using OtomasyonMakro.Helpers;
using OtomasyonMakro.Services;
using Xunit;

namespace OtomasyonMakro.Tests;

public class VariableResolverTests
{
    [Fact]
    public void Expand_ReplacesEnvVariable()
    {
        var result = VariableResolver.Expand("{{env:USERNAME}}");
        Assert.False(string.IsNullOrWhiteSpace(result));
        Assert.DoesNotContain("{{", result);
    }

    [Fact]
    public void Expand_ReplacesUserAlias()
    {
        var result = VariableResolver.Expand("Merhaba {{user}}");
        Assert.Contains(Environment.UserName, result);
    }

    [Fact]
    public void Expand_UnknownTokenLeftIntact()
    {
        var result = VariableResolver.Expand("{{unknown_token}}");
        Assert.Equal("{{unknown_token}}", result);
    }
}

public class ScheduleServiceTests
{
    [Theory]
    [InlineData("1", DayOfWeek.Monday, true)]
    [InlineData("0", DayOfWeek.Sunday, true)]
    [InlineData("1", DayOfWeek.Sunday, false)]
    public void IsScheduledDay_MatchesExpected(string days, DayOfWeek day, bool expected)
    {
        var now = new DateTime(2026, 6, 1);
        while (now.DayOfWeek != day)
        {
            now = now.AddDays(1);
        }

        Assert.Equal(expected, ScheduleService.IsScheduledDay(days, now));
    }

    [Fact]
    public void TimeMatches_WithinOneMinute()
    {
        var now = new DateTime(2026, 6, 3, 9, 0, 30);
        Assert.True(ScheduleService.TimeMatches("09:00", now));
    }
}
