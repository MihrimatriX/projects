using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class CategoryDefaultsTests
{
    [Theory]
    [InlineData("devenv", UsageCategory.Productive)]
    [InlineData("Code", UsageCategory.Productive)]
    [InlineData("steam", UsageCategory.Distracting)]
    [InlineData("discord", UsageCategory.Distracting)]
    [InlineData("chrome", UsageCategory.Neutral)]
    [InlineData("explorer", UsageCategory.Neutral)]
    public void GetCategory_uses_builtin_rules(string process, UsageCategory expected)
    {
        Assert.Equal(expected, CategoryDefaults.GetCategory(process));
    }
}
