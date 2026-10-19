using EkranZamani_WinUI.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace EkranZamani_WinUI.Services;

public static class AppNavigation
{
    public static ShellPage? Shell { get; set; }
    public static DailyPageViewModel? DailyViewModel { get; set; }

    public static void GoToDaily() => Shell?.NavigateTo("daily");
    public static void GoToWeekly() => Shell?.NavigateTo("weekly");
    public static void GoToGoals() => Shell?.NavigateTo("goals");
    public static void GoToCategories() => Shell?.NavigateTo("categories");
    public static void GoToSettings() => Shell?.NavigateTo("settings");
}
