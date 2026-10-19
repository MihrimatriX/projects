using EkranZamani.Models;
using EkranZamani.Services;
using Xunit;

namespace EkranZamani.Tests;

public class AutoCategorizationServiceTests
{
    [Fact]
    public void Predict_matches_similar_process_to_rule()
    {
        var rules = new List<CategoryRule>
        {
            new() { Id = 1, Pattern = "code", Category = UsageCategory.Productive, Priority = 100 }
        };

        var service = new AutoCategorizationService();
        var result = service.Predict("Code - Insiders", rules);

        Assert.Equal(UsageCategory.Productive, result);
    }
}
