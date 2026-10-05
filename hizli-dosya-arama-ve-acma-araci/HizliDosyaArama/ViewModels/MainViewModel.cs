using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using HizliDosyaArama.Models;
using HizliDosyaArama.Services;
using NHotkey;
using NHotkey.Wpf;

namespace HizliDosyaArama.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly DatabaseService _db;
    private readonly IndexerService _indexer;
    private readonly DispatcherTimer _debounce;

    [ObservableProperty] private string _searchQuery = string.Empty;
    [ObservableProperty] private FileItem? _selectedItem;
    [ObservableProperty] private long _indexedCount;
    [ObservableProperty] private bool _isIndexing;
    [ObservableProperty] private bool _showEmptyState;
    [ObservableProperty] private bool _showResults;
    [ObservableProperty] private bool _showErrorBanner;
    [ObservableProperty] private string _errorMessage = string.Empty;
    [ObservableProperty] private int _searchElapsedMs;
    [ObservableProperty] private int _resultCount;
    [ObservableProperty] private string _footerAction = "Dosya seçin";
    [ObservableProperty] private string _groupLabel = "Son dosyalar";
    [ObservableProperty] private string _toastMessage = string.Empty;
    [ObservableProperty] private bool _showToast;

    public ObservableCollection<FileItem> Results { get; } = [];
    public ObservableCollection<AliasItem> Aliases { get; } = [];

    public event Action? RequestShow;
    public event Action? RequestHide;

    public MainViewModel()
    {
        _db = new DatabaseService();
        _indexer = new IndexerService(_db);
        _indexer.StatusChanged += OnIndexerStatus;
        _indexer.IndexingCompleted += OnIndexingCompleted;

        _debounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(60) };
        _debounce.Tick += (_, _) => { _debounce.Stop(); ExecuteSearch(); };

        LoadAliases();
        IndexedCount = _db.GetIndexedCount();

        // Global Alt+F kısayolu (NHotkey, RegisterHotKey); başka uygulama aldıysa sessizce atlanır, tepsi menüsü yine çalışır
        try
        {
            HotkeyManager.Current.AddOrReplace("ShowSearch", Key.F, ModifierKeys.Alt, OnGlobalHotkey);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Hotkey kaydı başarısız: {ex.Message}");
        }

        if (IndexedCount == 0)
            StartIndexing();
    }

    private void LoadAliases()
    {
        var path = Path.Combine(_db.DataFolder, "aliases.json");
        try
        {
            if (!File.Exists(path))
            {
                var defaults = new[] { new { name = "proje", query = "proje" }, new { name = "docs", query = "doc" }, new { name = "dev", query = "dev" } };
                File.WriteAllText(path, JsonSerializer.Serialize(defaults, new JsonSerializerOptions { WriteIndented = true }));
            }

            var json = File.ReadAllText(path);
            var items = JsonSerializer.Deserialize<List<AliasDto>>(json) ?? [];
            foreach (var item in items)
                Aliases.Add(new AliasItem { Name = item.name, Query = item.query });
        }
        catch
        {
            // ponytail: bozuk/yazılamayan alias dosyası uygulamayı düşürmez
        }
    }

    private void OnIndexerStatus(string status) => RunOnUi(() =>
    {
        IsIndexing = _indexer.IsIndexing;
        if (status.StartsWith("Hata:", StringComparison.OrdinalIgnoreCase))
        {
            ShowErrorBanner = true;
            ErrorMessage = status[5..].Trim();
        }
        else
        {
            ShowErrorBanner = false;
            IndexedCount = _db.GetIndexedCount();
        }
    });

    private void OnIndexingCompleted() => RunOnUi(() =>
    {
        IsIndexing = false;
        IndexedCount = _db.GetIndexedCount();
        // Hata banner'ı burada kapatılmaz: "Hata:" durumu hemen önce geldiyse görünür kalmalı (başarıda "Hazır" durumu zaten kapatır)
        ExecuteSearch();
    });

    private void OnGlobalHotkey(object? sender, HotkeyEventArgs e)
    {
        e.Handled = true;
        RunOnUi(() => RequestShow?.Invoke());
    }

    // İndeksleyici olayları arka plan thread'inden gelir; bağlı özellikler ve Results yalnızca UI thread'inde değiştirilmeli
    private static void RunOnUi(Action action)
    {
        var dispatcher = System.Windows.Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
            action();
        else
            dispatcher.BeginInvoke(action);
    }

    partial void OnSearchQueryChanged(string value)
    {
        SyncAliasState(value.Trim());
        _debounce.Stop();
        _debounce.Start();
    }

    private void SyncAliasState(string query)
    {
        foreach (var alias in Aliases)
            alias.IsActive = string.Equals(alias.Query, query, StringComparison.OrdinalIgnoreCase)
                          || string.Equals(alias.Name, query, StringComparison.OrdinalIgnoreCase);
    }

    public void ExecuteSearch()
    {
        var sw = Stopwatch.StartNew();
        Results.Clear();

        if (string.IsNullOrWhiteSpace(SearchQuery))
        {
            foreach (var r in _db.GetRecentFiles(50))
                Results.Add(ToItem(r, null, isRecent: true));
            GroupLabel = "Son dosyalar";
        }
        else
        {
            // Vurgu ilk kelimeye uygulanır (çok kelimeli aramada tam sorgu adda bitişik geçmeyebilir).
            var highlight = DatabaseService.ParseQuery(SearchQuery).Terms.FirstOrDefault();
            foreach (var r in _db.SearchFiles(SearchQuery))
                Results.Add(ToItem(r, highlight));
            GroupLabel = $"{Results.Count} sonuç";
        }

        sw.Stop();
        SearchElapsedMs = Math.Max(1, (int)sw.ElapsedMilliseconds);
        ResultCount = Results.Count;
        ShowEmptyState = Results.Count == 0 && !IsIndexing;
        ShowResults = Results.Count > 0;
        SelectedItem = Results.Count > 0 ? Results[0] : null;
        UpdateFooter();
    }

    partial void OnSelectedItemChanged(FileItem? value) => UpdateFooter();

    private void UpdateFooter()
    {
        FooterAction = SelectedItem is null ? "Sonuç yok" : $"{SelectedItem.FileName} aç";
    }

    private static FileItem ToItem(IndexedFileData r, string? query, bool isRecent = false) =>
        new(r.FileName, r.FilePath, r.Extension, r.LastWriteTime, query, isRecent);

    [RelayCommand]
    public void StartIndexing() => _indexer.StartIndexing();

    [RelayCommand]
    public void ApplyAlias(AliasItem? alias)
    {
        if (alias is null) return;
        SearchQuery = alias.Query;
        ExecuteSearch();
    }

    // Silinmiş/taşınmış dosya: sessizce hiçbir şey yapmamak yerine bildir ve indeksten çıkar.
    private bool EnsureExists(FileItem item)
    {
        if (File.Exists(item.FilePath)) return true;
        _db.RemoveFile(item.FilePath);
        ExecuteSearch();
        IndexedCount = _db.GetIndexedCount();
        ShowToastMessage($"Bulunamadı, listeden kaldırıldı: {item.FileName}");
        return false;
    }

    [RelayCommand]
    public void OpenFile(FileItem? item)
    {
        if (item is null || !EnsureExists(item)) return;
        try
        {
            Process.Start(new ProcessStartInfo(item.FilePath) { UseShellExecute = true });
            _db.RecordRecentAccess(new IndexedFileData
            {
                FileName = item.FileName,
                FilePath = item.FilePath,
                Extension = item.Extension,
                Size = 0,
                LastWriteTime = item.LastWriteTime
            });
            ShowToastMessage($"Açıldı: {item.FileName}");
            RequestHide?.Invoke();
        }
        catch (Exception ex)
        {
            ShowToastMessage($"Açılamadı: {ex.Message}");
        }
    }

    [RelayCommand]
    public void CopyPath(FileItem? item)
    {
        if (item is null) return;
        try
        {
            System.Windows.Clipboard.SetText(item.FilePath);
            ShowToastMessage("Yol kopyalandı");
            RequestHide?.Invoke();
        }
        catch (Exception ex)
        {
            ShowToastMessage($"Kopyalanamadı: {ex.Message}");
        }
    }

    [RelayCommand]
    public void OpenFolder(FileItem? item)
    {
        if (item is null || !EnsureExists(item)) return;
        try
        {
            Process.Start("explorer.exe", $"/select,\"{item.FilePath}\"");
            ShowToastMessage($"{item.FileName} klasörü");
            RequestHide?.Invoke();
        }
        catch (Exception ex)
        {
            ShowToastMessage($"Klasör açılamadı: {ex.Message}");
        }
    }

    private void ShowToastMessage(string message)
    {
        ToastMessage = message;
        ShowToast = true;
    }

    public void HideToast() => ShowToast = false;

    private sealed class AliasDto
    {
        public string name { get; set; } = string.Empty;
        public string query { get; set; } = string.Empty;
    }
}
