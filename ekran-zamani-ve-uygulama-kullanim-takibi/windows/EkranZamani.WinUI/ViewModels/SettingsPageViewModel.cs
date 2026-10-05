using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranZamani.Models;
using EkranZamani.Services;
using EkranZamani_WinUI.Models;
using EkranZamani_WinUI.Services;
using System.Collections.ObjectModel;

namespace EkranZamani_WinUI.ViewModels;

public partial class SettingsPageViewModel : ObservableObject
{
    private AppSettings _snapshot = new();

    [ObservableProperty] private string _idleThresholdMinutes = "5";
    [ObservableProperty] private string _retentionDays = "0";
    [ObservableProperty] private bool _logWindowTitles = true;
    [ObservableProperty] private bool _enableBrowserExtension = true;
    [ObservableProperty] private bool _enableSyncApi;
    [ObservableProperty] private string _newBlacklistEntry = string.Empty;
    [ObservableProperty] private string _saveStatus = "Değişiklik yok";
    [ObservableProperty] private bool _isDirty;
    [ObservableProperty] private bool _showSyncError;
    [ObservableProperty] private string _syncSummaryTitle = "Sync kapalı";
    [ObservableProperty] private string _syncSummaryDesc = "Self-host API açılana kadar dış bağlantı kurulmaz.";
    [ObservableProperty] private string _blacklistError = string.Empty;
    [ObservableProperty] private string _importStatus = "Dosya seçilmedi.";
    [ObservableProperty] private bool _canExportCsv;
    [ObservableProperty] private string _blacklistCountLabel = "0 kural";

    public ObservableCollection<BlacklistEntryView> BlacklistEntries { get; } = new();

    public SettingsPageViewModel()
    {
        LoadFromSettings();
        _snapshot = BuildSettingsSnapshot();
    }

    partial void OnIdleThresholdMinutesChanged(string value) => MarkDirty();
    partial void OnRetentionDaysChanged(string value) => MarkDirty();
    partial void OnLogWindowTitlesChanged(bool value) => MarkDirty();
    partial void OnEnableBrowserExtensionChanged(bool value) => MarkDirty();
    partial void OnEnableSyncApiChanged(bool value)
    {
        UpdateSyncSummary();
        ShowSyncError = value && !AppServices.SyncApi.IsRunning;
        MarkDirty();
    }

    private void MarkDirty()
    {
        IsDirty = true;
        SaveStatus = "Kaydedilmemiş değişiklikler";
    }

    private void LoadFromSettings()
    {
        var s = AppServices.Settings.Current;
        IdleThresholdMinutes = s.IdleThresholdMinutes.ToString();
        RetentionDays = s.RetentionDays.ToString();
        LogWindowTitles = s.LogWindowTitles;
        EnableBrowserExtension = s.EnableBrowserExtension;
        EnableSyncApi = s.EnableSyncApi;

        BlacklistEntries.Clear();
        foreach (var entry in s.AppBlacklist)
            BlacklistEntries.Add(new BlacklistEntryView(entry));

        UpdateBlacklistLabel();
        UpdateSyncSummary();
        ShowSyncError = s.EnableSyncApi && !AppServices.SyncApi.IsRunning;
        CanExportCsv = AppServices.Database.GetAppUsageSummary(1).Count > 0;
        IsDirty = false;
        SaveStatus = "Değişiklik yok";
    }

    private void UpdateSyncSummary()
    {
        if (EnableSyncApi)
        {
            SyncSummaryTitle = AppServices.SyncApi.IsRunning ? "Sync aktif" : "Sync hatası";
            SyncSummaryDesc = AppServices.SyncApi.IsRunning
                ? $"127.0.0.1:{AppServices.Settings.Current.SyncApiPort} dinleniyor."
                : "Yerel API yanıt vermiyor; veri cihazda korunuyor.";
        }
        else
        {
            SyncSummaryTitle = "Sync kapalı";
            SyncSummaryDesc = "Self-host API açılana kadar dış bağlantı kurulmaz.";
        }
    }

    [RelayCommand]
    private void AddBlacklistEntry()
    {
        BlacklistError = string.Empty;
        if (!SensitiveAppFilter.IsValidBlacklistEntry(NewBlacklistEntry))
        {
            BlacklistError = "Geçerli bir exe adı veya yol deseni girin.";
            return;
        }

        var entry = NewBlacklistEntry.Trim();
        if (BlacklistEntries.Any(e => e.Pattern.Equals(entry, StringComparison.OrdinalIgnoreCase)))
        {
            BlacklistError = "Bu kural zaten listede.";
            return;
        }

        BlacklistEntries.Add(new BlacklistEntryView(entry));
        NewBlacklistEntry = string.Empty;
        UpdateBlacklistLabel();
        MarkDirty();
    }

    [RelayCommand]
    private void RemoveBlacklistEntry(BlacklistEntryView? entry)
    {
        if (entry == null) return;
        BlacklistEntries.Remove(entry);
        UpdateBlacklistLabel();
        MarkDirty();
    }

    private void UpdateBlacklistLabel() =>
        BlacklistCountLabel = BlacklistEntries.Count == 1 ? "1 kural" : $"{BlacklistEntries.Count} kural";

    [RelayCommand]
    private async Task ImportActivityWatchAsync()
    {
        if (App.Window == null) return;
        var path = await WinUiFileDialogs.PickOpenFileAsync(App.Window, new[] { ".json" });
        if (path == null) return;
        try
        {
            int count = AppServices.ActivityWatch.ImportFromFile(path);
            ImportStatus = $"{count} olay içe aktarıldı.";
            CanExportCsv = true;
        }
        catch (Exception ex)
        {
            ImportStatus = ex.Message;
        }
    }

    [RelayCommand]
    private void ExportCsv()
    {
        try
        {
            var path = AppServices.Export.SaveToDownloads(AppServices.Export.ExportCsv(0), "csv");
            ImportStatus = $"CSV: {path}";
        }
        catch (Exception ex)
        {
            ImportStatus = ex.Message;
        }
    }

    [RelayCommand]
    private void RetrySync()
    {
        AppServices.RestartSyncApi();
        ShowSyncError = EnableSyncApi && !AppServices.SyncApi.IsRunning;
        UpdateSyncSummary();
    }

    [RelayCommand]
    private void Save()
    {
        if (!int.TryParse(IdleThresholdMinutes, out var idle) || idle is < 1 or > 120)
        {
            SaveStatus = "Boşta eşiği 1–120 dakika olmalı.";
            return;
        }
        if (!int.TryParse(RetentionDays, out var keep) || keep is < 0 or > 3650)
        {
            SaveStatus = "Saklama süresi 0–3650 gün olmalı (0 = süresiz).";
            return;
        }

        var settings = BuildSettingsSnapshot();
        AppServices.Settings.Save(settings);
        SettingsApplier.ApplySavedSettings(settings);
        AppServices.RestartSyncApi();
        AppServices.Database.PurgeOlderThan(settings.RetentionDays);

        _snapshot = settings;
        IsDirty = false;
        SaveStatus = "Kaydedildi";
        UpdateSyncSummary();
        ShowSyncError = EnableSyncApi && !AppServices.SyncApi.IsRunning;
    }

    [RelayCommand]
    private void DeleteAllData()
    {
        AppServices.Database.DeleteAllData();
        AppServices.Categories.Refresh();
        CanExportCsv = false;
        SaveStatus = "Tüm veriler silindi.";
    }

    public AppSettings BuildSettingsSnapshot()
    {
        var settings = AppServices.Settings.Current;
        settings.IdleThresholdMinutes = int.TryParse(IdleThresholdMinutes, out var idle) ? Math.Clamp(idle, 1, 120) : 5;
        settings.RetentionDays = int.TryParse(RetentionDays, out var keep) ? Math.Clamp(keep, 0, 3650) : 0;
        settings.LogWindowTitles = LogWindowTitles;
        settings.EnableBrowserExtension = EnableBrowserExtension;
        settings.EnableSyncApi = EnableSyncApi;
        settings.AppBlacklist = BlacklistEntries.Select(e => e.Pattern).ToList();
        return settings;
    }

    public bool HasUnsavedChanges() => IsDirty;
}
