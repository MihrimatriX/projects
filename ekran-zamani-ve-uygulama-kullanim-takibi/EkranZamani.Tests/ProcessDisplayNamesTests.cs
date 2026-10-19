using EkranZamani.Helpers;
using Xunit;

namespace EkranZamani.Tests;

public class ProcessDisplayNamesTests
{
    [Theory]
    [InlineData("chrome", "Google Chrome")]
    [InlineData("msedge", "Microsoft Edge")]
    [InlineData("Code.exe", "VS Code")]
    [InlineData("unknownapp", "unknownapp")]
    public void GetFriendlyName_maps_known_processes(string input, string expected)
    {
        Assert.Equal(expected, ProcessDisplayNames.GetFriendlyName(input));
    }
}
