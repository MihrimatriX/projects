using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranZamani.Helpers;
using EkranZamani.Models;
using EkranZamani.Services;
using EkranZamani_WinUI.Models;
using EkranZamani_WinUI.Services;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using System.Collections.ObjectModel;

namespace EkranZamani_WinUI.ViewModels;

public partial class DailyPageViewModel : ObservableObject
{
    private readonly DatabaseService _db = AppServices.Database;
    private readonly CategoryService _categories = AppServices.Categories;
    private readonly ExportService _export = AppServices.Export;
    private readonly DispatcherQueue _dispatcher;
    private int _dayOffset;

    [ObservableProperty] private string _heroTime = "0 dk";
    [ObservableProperty] private string _heroMeta = string.Empty;
    [ObservableProperty] private string _dateLabel = string.Empty;
    [ObservableProperty] private string _statusText = string.Empty;
    [ObservableProperty] private string _idleNote = string.Empty;
    [ObservableProperty] private bool _showTimeline = true;
    [ObservableProperty] private bool _hasWebDomains;

    public Visibility TimelineVisibility => ShowTimeline ? Visibility.Visible : Visibility.Collapsed;
    public Visibility WebDomainsVisibility => HasWebDomains ? Visibility.Visible : Visibility.Collapsed;

    public ObservableCollection<AppRowView> TopApps { get; } = new();
    public ObservableCollection<TimelineSegmentView> TimelineSegments { get; } = new();
    public ObservableCollection<CategoryShareView> CategoryShares { get; } = new();
    public ObservableCollection<WebDomainRowView> WebDomains { get; } = new();

    public DailyPageViewModel(DispatcherQueue dispatcher)
    {
        _dispatcher = dispatcher;
        AppTracking.Instance.Changed += () => _dispatcher.TryEnqueue(UpdateLiveState);
        Refresh();
        // ponytail: defer tracking until shell visible — timer + Win32 off UI thread during XAML load = crash
        _dispatcher.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () =>
        {
            AppTracking.Instance.Bind(dispatcher);
        });
    }

    private void UpdateLiveState() => StatusText = AppTracking.Instance.StatusText;

    [RelayCommand]
    private void PreviousDay()
    {
        _dayOffset = Math.Min(_dayOffset + 1, 30);
        Refresh();
    }

    [RelayCommand]
    private void NextDay()
    {
        if (_dayOffset > 0) _dayOffset--;
        Refresh();
    }

    [RelayCommand]
    private void ExportCsv() => Export("csv", _export.ExportCsv(_dayOffset));

    [RelayCommand]
    private void ExportJson() => Export("json", _export.ExportJson(_dayOffset));

    [RelayCommand]
    private void Refresh()
    {
        var day = DateTime.Today.AddDays(-_dayOffset);
        DateLabel = day.ToString("d MMMM yyyy dddd", new System.Globalization.CultureInfo("tr-TR"));
        HeroMeta = $"Bilgisayar başında · {day:d MMMM yyyy}";

        var rawSummary = _db.GetAppUsageSummaryForDaysAgo(_dayOffset);
        int totalSec = rawSummary.Sum(a => a.TotalSeconds);
        HeroTime = FormatDurationLong(totalSec);

        int productive = 0, distracting = 0, communication = 0, neutral = 0, idleSec = 0;
        TopApps.Clear();
        int rank = 0;
        foreach (var raw in rawSummary.OrderByDescending(a => a.TotalSeconds).Take(8))
        {
            if (string.Equals(raw.ProcessName, "Boşta", StringComparison.OrdinalIgnoreCase))
            {
                idleSec += raw.TotalSeconds;
                continue;
            }

            var cat = _categories.GetCategory(raw.ProcessName);
            switch (cat)
            {
                case UsageCategory.Productive: productive += raw.TotalSeconds; break;
                case UsageCategory.Distracting: distracting += raw.TotalSeconds; break;
                case UsageCategory.Communication: communication += raw.TotalSeconds; break;
                default: neutral += raw.TotalSeconds; break;
            }

            rank++;
            TopApps.Add(new AppRowView(raw.ProcessName, raw.TotalSeconds, cat, rank, totalSec));
        }

        IdleNote = idleSec > 0 ? $"Boşta süre ayrı satırda: {FormatDurationLong(idleSec)}" : string.Empty;
        LoadTimeline(_dayOffset);
        LoadCategoryShares(productive, distracting, communication, neutral);
        LoadWebDomains(_dayOffset);

        if (_dayOffset == 0)
        {
            var settings = AppServices.Settings.Current;
            AppServices.FocusGoals.CheckAndNotify(settings.EnableGoalNotifications);
            AppServices.UsageAlerts.CheckDistractingLimit(settings);
        }

        UpdateLiveState();
    }

    private void LoadWebDomains(int daysAgo)
    {
        WebDomains.Clear();
        if (!AppServices.Settings.Current.EnableBrowserExtension)
        {
            HasWebDomains = false;
            OnPropertyChanged(nameof(WebDomainsVisibility));
            return;
        }

        var domains = _db.GetWebDomainSummaryForDaysAgo(daysAgo);
        int max = domains.Count > 0 ? domains.Max(d => d.TotalSeconds) : 1;
        foreach (var d in domains)
            WebDomains.Add(new WebDomainRowView(d.Domain, d.TotalSeconds, max));
        HasWebDomains = WebDomains.Count > 0;
        OnPropertyChanged(nameof(WebDomainsVisibility));
    }

    private void LoadTimeline(int daysAgo)
    {
        TimelineSegments.Clear();
        ShowTimeline = true;
        OnPropertyChanged(nameof(TimelineVisibility));

        var records = _db.GetUsageRecords(daysAgo, ascending: true);
        var segments = TimelineBuilder.Build(records, _categories.GetCategory, daysAgo);
        foreach (var segment in segments)
            TimelineSegments.Add(new TimelineSegmentView(segment));

        if (TimelineSegments.Count == 0)
            HeroMeta += " · Henüz kayıt yok";
    }

    private void LoadCategoryShares(int productive, int distracting, int communication, int neutral)
    {
        CategoryShares.Clear();
        var total = (double)(productive + distracting + communication + neutral);
        if (productive > 0)
            CategoryShares.Add(new CategoryShareView("Verimli", productive, CategoryColorHelper.ToHex(UsageCategory.Productive), total));
        if (communication > 0)
            CategoryShares.Add(new CategoryShareView("İletişim", communication, CategoryColorHelper.ToHex(UsageCategory.Communication), total));
        if (neutral > 0)
            CategoryShares.Add(new CategoryShareView("Nötr", neutral, CategoryColorHelper.ToHex(UsageCategory.Neutral), total));
        if (distracting > 0)
            CategoryShares.Add(new CategoryShareView("Dikkat dağıtıcı", distracting, CategoryColorHelper.ToHex(UsageCategory.Distracting), total));
    }

    public void ExportJsonFromTray() => ExportJsonCommand.Execute(null);
    public void ToggleTrackingFromTray() => AppTracking.Instance.Toggle();

    private void Export(string ext, string content)
    {
        try
        {
            var path = _export.SaveToDownloads(content, ext);
            StatusText = $"{ext.ToUpperInvariant()}: {path}";
        }
        catch (Exception ex)
        {
            StatusText = ex.Message;
        }
    }

    private static string FormatDurationLong(int seconds)
    {
        var t = TimeSpan.FromSeconds(seconds);
        if (t.TotalHours >= 1)
            return $"{(int)t.TotalHours}s {t.Minutes}dk";
        if (t.TotalMinutes >= 1)
            return $"{t.Minutes}dk";
        return $"{t.Seconds} sn";
    }
}
