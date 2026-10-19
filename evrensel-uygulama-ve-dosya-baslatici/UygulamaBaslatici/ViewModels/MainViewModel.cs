using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Windows.Data;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UygulamaBaslatici.Models;
using UygulamaBaslatici.Services;

namespace UygulamaBaslatici.ViewModels;

public partial class MainViewModel : ObservableObject, IDisposable
{
    private readonly DatabaseService _db;
    private readonly AppScannerService _scanner;
    private readonly System.Timers.Timer _debounce = new(100) { AutoReset = false };

    [ObservableProperty] private string _searchQuery = "";
    [ObservableProperty] private LauncherItem? _selectedItem;
    [ObservableProperty] private bool _isScanning;
    [ObservableProperty] private int _scanFoundCount;
    [ObservableProperty] private string _scanStatusText = "";
    [ObservableProperty] private bool _hotkeyFailed;

    public ObservableCollection<LauncherItem> Results { get; } = [];
    public ICollectionView ResultsView { get; }

    public int ResultCount => Results.Count;
    public bool IsShellMode => SearchQuery.TrimStart().StartsWith('>');
    public bool ShowEmptyState => !IsShellMode && !string.IsNullOrWhiteSpace(SearchQuery)
        && Results.All(i => i.Type is not ("App" or "Path"));
    public string EmptyQueryText => SearchQuery.Trim();

    public event Action? RequestHide;

    public MainViewModel()
    {
        _db = new DatabaseService();
        _scanner = new AppScannerService(_db);
        _scanner.StatusChanged += OnScanStatus;
        _scanner.FoundCountChanged += count => App.Current.Dispatcher.Invoke(() => ScanFoundCount = count);
        _scanner.ScanningCompleted += OnScanCompleted;

        ResultsView = CollectionViewSource.GetDefaultView(Results);
        ResultsView.GroupDescriptions.Add(new PropertyGroupDescription(nameof(LauncherItem.Group)));

        _debounce.Elapsed += (_, _) => App.Current.Dispatcher.Invoke(ExecuteSearch);

        _scanner.ScanStartMenu();
    }

    private void OnScanStatus(string status)
    {
        App.Current.Dispatcher.Invoke(() =>
        {
            ScanStatusText = status;
            IsScanning = _scanner.IsScanning;
        });
    }

    private void OnScanCompleted()
    {
        App.Current.Dispatcher.Invoke(() =>
        {
            IsScanning = false;
            ScanStatusText = "";
            ExecuteSearch();
        });
    }

    partial void OnSearchQueryChanged(string value)
    {
        _debounce.Stop();
        _debounce.Start();
        OnPropertyChanged(nameof(IsShellMode));
        OnPropertyChanged(nameof(ShowEmptyState));
        OnPropertyChanged(nameof(EmptyQueryText));
    }

    public void ExecuteSearch()
    {
        Results.Clear();
        var q = SearchQuery.Trim();

        if (string.IsNullOrEmpty(q))
        {
            foreach (var app in _db.GetTopApps(5))
                Results.Add(new LauncherItem(app.Name, app.Path, "App", "Uygulamalar", app.UsageCount));
        }
        else if (q.StartsWith('>'))
        {
            var cmd = q[1..].TrimStart();
            if (!string.IsNullOrEmpty(cmd))
                Results.Add(new LauncherItem(cmd, cmd, "Command", "Komut"));
        }
        else
        {
            // Var olan bir dosya/klasör yolu yazıldıysa (%TEMP%, C:\Windows ...) doğrudan açılabilir.
            if (TryResolvePath(q) is { } path)
                Results.Add(new LauncherItem(System.IO.Path.GetFileName(path.TrimEnd('\\')) is { Length: > 0 } n ? n : path,
                    path, "Path", "Dosya"));

            var apps = _db.SearchApps(q);
            foreach (var app in apps)
                Results.Add(new LauncherItem(app.Name, app.Path, "App", "Uygulamalar", app.UsageCount));

            if (apps.Count > 0 && q.Length >= 2)
            {
                var url = $"https://www.google.com/search?q={Uri.EscapeDataString(q)}";
                Results.Add(new LauncherItem($"Google'da ara: \"{q}\"", url, "WebSearch", "Web"));
            }
        }

        SelectedItem = Results.FirstOrDefault();
        OnPropertyChanged(nameof(ResultCount));
        OnPropertyChanged(nameof(ShowEmptyState));
        ResultsView.Refresh();
    }

    [RelayCommand]
    public void StartScanning() => _scanner.ScanStartMenu();

    [RelayCommand]
    public void LaunchWebSearch()
    {
        var q = SearchQuery.Trim();
        if (string.IsNullOrEmpty(q) || IsShellMode) return;
        LaunchUrl($"https://www.google.com/search?q={Uri.EscapeDataString(q)}");
    }

    [RelayCommand]
    public void LaunchItem(LauncherItem? item)
    {
        if (item == null) return;
        try
        {
            switch (item.Type)
            {
                case "App":
                    Process.Start(new ProcessStartInfo(item.Path) { UseShellExecute = true });
                    _db.IncrementUsage(item.Path);
                    break;
                case "Path":
                    Process.Start(new ProcessStartInfo(item.Path) { UseShellExecute = true });
                    break;
                case "Command":
                    Process.Start(new ProcessStartInfo("powershell.exe", BuildPowerShellArguments(item.Path)) { UseShellExecute = true });
                    break;
                case "WebSearch":
                    LaunchUrl(item.Path);
                    break;
            }
            RequestHide?.Invoke();
            SearchQuery = "";
        }
        catch (Exception ex) { ReportLaunchError(item, ex); }
    }

    /// <summary>Ctrl+Enter: seçili uygulama kısayolunu ya da dosyayı Gezgin'de seçili olarak gösterir.</summary>
    public void OpenItemLocation(LauncherItem? item)
    {
        if (item is not { Type: "App" or "Path" }) return;
        try
        {
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{item.Path}\"") { UseShellExecute = true });
            RequestHide?.Invoke();
        }
        catch (Exception ex) { ReportLaunchError(item, ex); }
    }

    private void ReportLaunchError(LauncherItem item, Exception ex)
    {
        // Kaldırılmış uygulamanın kısayolu: listeden çıkar ki tekrar karşımıza gelmesin.
        if (item.Type == "App" && !System.IO.File.Exists(item.Path))
        {
            _db.RemoveApp(item.Path);
            ExecuteSearch();
            System.Windows.MessageBox.Show($"\"{item.Name}\" kısayolu artık yok; listeden kaldırıldı.", "Komut Paleti",
                System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
            return;
        }
        System.Windows.MessageBox.Show($"\"{item.Name}\" başlatılamadı:\n{ex.Message}", "Komut Paleti",
            System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning);
    }

    /// <summary>Komut penceresi çıktısı okunabilsin diye PowerShell açık kalır (-NoExit).</summary>
    public static string BuildPowerShellArguments(string command) =>
        $"-NoExit -NoProfile -Command \"{command.Replace("\"", "\\\"")}\"";

    /// <summary>Sorgu var olan bir dosya/klasör yoluysa (ortam değişkenleri açılarak) tam yolunu döndürür.</summary>
    public static string? TryResolvePath(string query)
    {
        var q = Environment.ExpandEnvironmentVariables(query.Trim().Trim('"'));
        // ponytail: ağ yolları (\\sunucu) her tuşta ağ sorgusu yapıp paleti dondurabileceği için atlanır.
        if (!System.IO.Path.IsPathFullyQualified(q) || q.StartsWith(@"\\")) return null;
        try
        {
            var full = System.IO.Path.GetFullPath(q);
            return System.IO.File.Exists(full) || System.IO.Directory.Exists(full) ? full : null;
        }
        catch (Exception) { return null; }
    }

    private static void LaunchUrl(string url) =>
        Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });

    public void Dispose() => _debounce.Dispose();
}
