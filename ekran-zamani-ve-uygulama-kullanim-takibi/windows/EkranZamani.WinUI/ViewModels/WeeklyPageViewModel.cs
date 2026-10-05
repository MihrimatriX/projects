using EkranZamani.Models;
using EkranZamani.Helpers;
using EkranZamani.Services;
using EkranZamani_WinUI.Models;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace EkranZamani_WinUI.ViewModels;

public partial class WeeklyPageViewModel : ObservableObject
{
    private readonly DatabaseService _db = AppServices.Database;
    private readonly CategoryService _categories = AppServices.Categories;

    [ObservableProperty] private string _weekRangeLabel = string.Empty;
    [ObservableProperty] private string _avgTotal = "—";
    [ObservableProperty] private string _avgProductive = "—";
    [ObservableProperty] private string _avgDistracting = "—";
    [ObservableProperty] private string _streakText = "0 gün";
    [ObservableProperty] private string _statusMessage = string.Empty;

    public ObservableCollection<WeeklyBarView> DailyBars { get; } = new();
    public ObservableCollection<CategoryShareView> CategoryShares { get; } = new();
    public ObservableCollection<HourlyBarView> HourlyBars { get; } = new();
    public ObservableCollection<string> Insights { get; } = new();

    public WeeklyPageViewModel() => Refresh();

    [RelayCommand]
    private void Refresh()
    {
        DailyBars.Clear();
        CategoryShares.Clear();
        HourlyBars.Clear();
        Insights.Clear();

        var settings = AppServices.Settings.Current;
        int streak = AppServices.Streak.ComputeStreak(settings.ProductiveStreakMinMinutes);
        StreakText = streak == 1 ? "1 gün" : $"{streak} gün";

        var daily = _db.GetDailyUsageSummary(7);
        var today = DateTime.Today;
        var weekStart = today.AddDays(-6);
        WeekRangeLabel = $"{weekStart:d MMM} – {today:d MMM yyyy}";

        var dayLabels = new[] { "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz" };
        int maxSec = daily.Count > 0 ? daily.Max(d => d.TotalSeconds) : 1;
        if (maxSec <= 0) maxSec = 1;

        for (int i = 0; i < 7; i++)
        {
            var day = weekStart.AddDays(i);
            var key = day.ToString("yyyy-MM-dd");
            var entry = daily.FirstOrDefault(d => d.Day == key);
            int sec = entry?.TotalSeconds ?? 0;
            // Pencere bugünden geriye 7 gün; etiket haftanın gününe göre seçilir (DayOfWeek: Pazar=0)
            DailyBars.Add(new WeeklyBarView(dayLabels[((int)day.DayOfWeek + 6) % 7], sec, maxSec, day.Date == today));
        }

        var apps = _db.GetAppUsageSummary(7);
        int productive = 0, distracting = 0, communication = 0, neutral = 0;
        foreach (var app in apps)
        {
            switch (_categories.GetCategory(app.ProcessName))
            {
                case UsageCategory.Productive: productive += app.TotalSeconds; break;
                case UsageCategory.Distracting: distracting += app.TotalSeconds; break;
                case UsageCategory.Communication: communication += app.TotalSeconds; break;
                default: neutral += app.TotalSeconds; break;
            }
        }

        var total = (double)(productive + distracting + communication + neutral);
        if (productive > 0)
            CategoryShares.Add(new CategoryShareView("Verimli", productive, "#34C759", total));
        if (communication > 0)
            CategoryShares.Add(new CategoryShareView("İletişim", communication, "#5856D6", total));
        if (neutral > 0)
            CategoryShares.Add(new CategoryShareView("Nötr", neutral, "#8E8E93", total));
        if (distracting > 0)
            CategoryShares.Add(new CategoryShareView("Dikkat dağıtıcı", distracting, "#FF3B30", total));

        int daysWithData = daily.Count(d => d.TotalSeconds > 0);
        if (daysWithData > 0)
        {
            int avg = (int)(daily.Sum(d => d.TotalSeconds) / (double)daysWithData);
            AvgTotal = FormatDuration(avg);
            AvgProductive = FormatDuration(productive / Math.Max(1, daysWithData));
            AvgDistracting = FormatDuration(distracting / Math.Max(1, daysWithData));
        }

        LoadHourlyBars();

        var topApp = apps.OrderByDescending(a => a.TotalSeconds).FirstOrDefault();
        var longest = daily.OrderByDescending(d => d.TotalSeconds).FirstOrDefault();
        if (longest != null && longest.TotalSeconds > 0)
        {
            var dayName = DateTime.TryParse(longest.Day, out var dt)
                ? dt.ToString("dddd", new System.Globalization.CultureInfo("tr-TR"))
                : longest.Day;
            Insights.Add($"{dayName} en uzun gün: {FormatDuration(longest.TotalSeconds)}");
        }
        if (topApp != null)
            Insights.Add($"En çok kullanılan: {ProcessDisplayNames.GetFriendlyName(topApp.ProcessName)} ({FormatDuration(topApp.TotalSeconds)} toplam)");
        if (streak > 0)
            Insights.Add($"Verimli gün serisi: {streak} gün (≥{settings.ProductiveStreakMinMinutes} dk/gün)");
        if (Insights.Count == 0)
            Insights.Add("Bu hafta henüz yeterli veri yok.");
    }

    private void LoadHourlyBars()
    {
        var hourly = _db.GetHourlyUsageSummary(0);
        var minutes = new double[24];
        for (int h = 0; h < 24; h++)
            minutes[h] = hourly.TryGetValue(h, out var sec) ? sec / 60.0 : 0;
        var max = minutes.Max();
        if (max <= 0) max = 1;
        for (int h = 0; h < 24; h++)
            HourlyBars.Add(new HourlyBarView(h, minutes[h], max));
    }

    [RelayCommand]
    private void OpenWeeklyReport()
    {
        try
        {
            var path = AppServices.WeeklyReport.SaveAndOpenReport();
            StatusMessage = $"Rapor: {path}";
        }
        catch (Exception ex)
        {
            StatusMessage = ex.Message;
        }
    }

    private static string FormatDuration(int seconds)
    {
        var t = TimeSpan.FromSeconds(seconds);
        if (t.TotalHours >= 1)
            return $"{(int)t.TotalHours}s {t.Minutes}dk";
        return $"{t.Minutes}dk";
    }
}
