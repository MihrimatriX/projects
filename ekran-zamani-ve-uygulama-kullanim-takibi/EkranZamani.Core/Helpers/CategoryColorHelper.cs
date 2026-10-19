using EkranZamani.Models;

namespace EkranZamani.Helpers;

public static class CategoryColorHelper
{
    public static string IdleHex => "#8E8E9359";

    public static string ToHex(UsageCategory category) => category switch
    {
        UsageCategory.Productive => "#34C759",
        UsageCategory.Distracting => "#FF3B30",
        UsageCategory.Communication => "#5856D6",
        _ => "#8E8E93"
    };
}
