using EkranZamani.Helpers;
using EkranZamani.Models;
using EkranZamani.Services;
using EkranZamani_WinUI.Helpers;
using Microsoft.UI.Xaml.Media;

namespace EkranZamani_WinUI.Models;

public sealed class TimelineSegmentView
{
    private const double TrackWidth = 960;

    public TimelineSegmentView(TimelineSegment segment)
    {
        ToolTip = segment.ToolTipText;
        Brush = WinUiColorHelper.BrushFromHex(segment.SegmentColorHex);
        LeftPx = segment.LeftPercent * TrackWidth / 100.0;
        WidthPx = Math.Max(2, segment.WidthPercent * TrackWidth / 100.0);
    }

    public string ToolTip { get; }
    public double LeftPx { get; }
    public Microsoft.UI.Xaml.Thickness Offset => new(LeftPx, 0, 0, 0);
    public double WidthPx { get; }
    public Brush Brush { get; }
}

public sealed class CategoryShareView
{
    public CategoryShareView(string label, int seconds, string hex, double totalSeconds)
    {
        Label = label;
        Brush = WinUiColorHelper.BrushFromHex(hex);
        Percent = totalSeconds > 0 ? (int)Math.Round(seconds / totalSeconds * 100) : 0;
        BarPixels = Math.Max(4, Percent * 2.0);
    }

    public string Label { get; }
    public Brush Brush { get; }
    public int Percent { get; }
    public double BarPixels { get; }
    public string PercentText => $"{Percent}%";
}

public sealed class AppRowView
{
    public AppRowView(string processName, int totalSeconds, UsageCategory category, int rank, int dayTotalSeconds)
    {
        DisplayName = ProcessDisplayNames.GetFriendlyName(processName);
        Initials = BuildInitials(DisplayName);
        FormattedTime = FormatTime(totalSeconds);
        BarPixels = Math.Max(4, dayTotalSeconds > 0 ? (double)totalSeconds / dayTotalSeconds * 120 : 0);
        BarBrush = WinUiColorHelper.BrushFromHex(CategoryColorHelper.ToHex(category));
        Rank = rank;
        RankLabel = rank.ToString();
        RankBrush = rank switch
        {
            1 => WinUiColorHelper.BrushFromHex("#FFD60A"),
            2 => WinUiColorHelper.BrushFromHex("#C0C0C0"),
            3 => WinUiColorHelper.BrushFromHex("#CD7F32"),
            _ => WinUiColorHelper.BrushFromHex("#F2F2F7")
        };
        RankForeground = rank == 3
            ? WinUiColorHelper.BrushFromHex("#FFFFFF")
            : WinUiColorHelper.BrushFromHex("#86868B");
    }

    public string DisplayName { get; }
    public string Initials { get; }
    public string FormattedTime { get; }
    public double BarPixels { get; }
    public Brush BarBrush { get; }
    public int Rank { get; }
    public string RankLabel { get; }
    public Brush RankBrush { get; }
    public Brush RankForeground { get; }

    private static string BuildInitials(string name)
    {
        var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2)
            return $"{parts[0][0]}{parts[1][0]}".ToUpperInvariant();
        return name.Length >= 2 ? name[..2].ToUpperInvariant() : name.ToUpperInvariant();
    }

    private static string FormatTime(int seconds)
    {
        var t = TimeSpan.FromSeconds(seconds);
        if (t.TotalHours >= 1)
            return $"{(int)t.TotalHours}s {t.Minutes}dk";
        return $"{t.Minutes}dk";
    }
}

public sealed class GoalRingView
{
    public GoalRingView(FocusGoalProgress progress)
    {
        Title = progress.Goal.Title;
        StatusText = progress.IsComplete
            ? $"Tamamlandı · {progress.FormattedCurrent}"
            : $"{progress.FormattedCurrent} / {progress.FormattedTarget}";
        PercentText = progress.IsComplete ? "✓" : $"{(int)progress.Percentage}%";
        Percentage = Math.Clamp(progress.Percentage, 0, 100);
        Progress = progress;
    }

    public string Title { get; }
    public string StatusText { get; }
    public string PercentText { get; }
    public double Percentage { get; }
    public FocusGoalProgress Progress { get; }
}

public sealed class WeeklyBarView
{
    public WeeklyBarView(string label, int totalSeconds, int maxSeconds, bool isToday)
    {
        Label = label;
        IsToday = isToday;
        ValueText = totalSeconds > 0 ? Format(totalSeconds) : "—";
        BarHeight = maxSeconds > 0 ? Math.Max(4, (double)totalSeconds / maxSeconds * 140) : 4;
    }

    public string Label { get; }
    public string ValueText { get; }
    public double BarHeight { get; }
    public bool IsToday { get; }

    private static string Format(int seconds)
    {
        var t = TimeSpan.FromSeconds(seconds);
        return t.TotalHours >= 1 ? $"{(int)t.TotalHours}s {t.Minutes}dk" : $"{t.Minutes}dk";
    }
}

public sealed class HourlyBarView
{
    public HourlyBarView(int hour, double minutes, double maxMinutes)
    {
        Label = $"{hour:00}";
        BarHeight = maxMinutes > 0 ? Math.Max(4, minutes / maxMinutes * 80) : 4;
        ToolTip = $"{hour:00}:00 — {minutes:F0} dk";
    }

    public string Label { get; }
    public double BarHeight { get; }
    public string ToolTip { get; }
}

public sealed class WebDomainRowView
{
    public WebDomainRowView(string domain, int totalSeconds, int maxSeconds)
    {
        Domain = domain;
        FormattedTime = Format(totalSeconds);
        BarPixels = maxSeconds > 0 ? Math.Max(4, (double)totalSeconds / maxSeconds * 160) : 4;
    }

    public string Domain { get; }
    public string FormattedTime { get; }
    public double BarPixels { get; }

    private static string Format(int seconds)
    {
        var t = TimeSpan.FromSeconds(seconds);
        return t.TotalHours >= 1 ? $"{(int)t.TotalHours}s {t.Minutes}dk" : $"{t.Minutes}dk";
    }
}

public sealed class CategorySuggestionView
{
    public CategorySuggestionView(CategorySuggestion suggestion)
    {
        Pattern = suggestion.Pattern;
        CategoryLabel = CategoryService.GetLabel(suggestion.SuggestedCategory);
        Reason = suggestion.Reason;
        Source = suggestion;
    }

    public string Pattern { get; }
    public string CategoryLabel { get; }
    public string Reason { get; }
    public CategorySuggestion Source { get; }
}

public sealed class StatChipView
{
    public StatChipView(string label, string value, string colorHex)
    {
        Label = label;
        Value = value;
        Brush = WinUiColorHelper.BrushFromHex(colorHex);
    }

    public string Label { get; }
    public string Value { get; }
    public Brush Brush { get; }
}

public sealed class BlacklistEntryView
{
    public BlacklistEntryView(string pattern)
    {
        Pattern = pattern;
        Initial = string.IsNullOrWhiteSpace(pattern) ? "?" : char.ToUpperInvariant(pattern.Trim()[0]).ToString();
    }

    public string Pattern { get; }
    public string Initial { get; }
}
