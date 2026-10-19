using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using ProjeLauncher.Models;
using ProjeLauncher.Services;

namespace ProjeLauncher.ViewModels;

public sealed partial class NavItem : ObservableObject
{
    public required string Label { get; init; }
    public required ScopeKind Kind { get; init; }
    public string? Value { get; init; }
    public string Glyph { get; init; } = "";
    /// <summary>Yigin ogeleri ikon yerine renk noktasi gosterir.</summary>
    public string? Color { get; init; }
    public bool IsHeader => Kind == ScopeKind.Header;
    [ObservableProperty] private int _count;
}

public sealed partial class ScreenshotItem(string path) : ObservableObject
{
    public string Path { get; } = path;
    public string Label => System.IO.Path.GetFileNameWithoutExtension(Path);
    [ObservableProperty] private ImageSource? _thumb;
}

public sealed partial class MainViewModel : ObservableObject
{
    private readonly StateStore _store;
    private readonly Action<ProcessStartInfo> _start;
    private LauncherState _state;
    private List<ProjectEntry> _all = [];
    private string _root = "";

    public ObservableCollection<ProjectEntry> Projects { get; } = [];
    public ObservableCollection<NavItem> NavItems { get; } = [];
    public ObservableCollection<ToolStatus> Toolchains { get; } = [];
    public ObservableCollection<ScreenshotItem> DetailShots { get; } = [];

    [ObservableProperty] private NavItem? _selectedNav;
    [ObservableProperty] private ExeFilter _exeFilter;
    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private ProjectEntry? _selectedProject;
    [ObservableProperty] private ProjectEntry? _detailProject;
    [ObservableProperty] private ScreenshotItem? _selectedShot;
    [ObservableProperty] private ImageSource? _detailImage;
    [ObservableProperty] private ReadmeSummary? _detailReadme;
    [ObservableProperty] private string _statusMessage = "Yükleniyor…";
    [ObservableProperty] private string _resultText = "";
    [ObservableProperty] private string _runningText = "";
    [ObservableProperty] private bool _isLoading;

    /// <summary>Kart kucuk resmi cozme genisligi (pencere DPI'sina gore ayarlanir).</summary>
    public int ThumbWidth { get; set; } = 400;
    public int DetailImageWidth { get; set; } = 1400;
    public string Root => _root;
    public IReadOnlyList<string> Recent => _state.Recent;

    public MainViewModel() : this(null, null) { }

    public MainViewModel(StateStore? store, Action<ProcessStartInfo>? start)
    {
        _store = store ?? new StateStore();
        _start = start ?? ProjectLaunchService.Start;
        _state = _store.Load();
    }

    partial void OnSearchTextChanged(string value)
    {
        DetailProject = null;
        ApplyFilter();
    }

    partial void OnExeFilterChanged(ExeFilter value) => ApplyFilter();

    partial void OnSelectedNavChanged(NavItem? oldValue, NavItem? newValue)
    {
        if (newValue is { IsHeader: true }) { SelectedNav = oldValue; return; }
        DetailProject = null;
        ApplyFilter();
    }

    [RelayCommand]
    public async Task RefreshAsync()
    {
        IsLoading = true;
        try
        {
            var root = RepoRoot.Find();
            var list = await Task.Run(() => ProjectCatalogService.Load(root));
            _root = root;
            var favs = _state.Favorites.ToHashSet(StringComparer.OrdinalIgnoreCase);
            foreach (var p in list) p.IsFavorite = favs.Contains(p.Folder);

            var selected = SelectedProject?.Folder;
            var detail = DetailProject?.Folder;
            _all = list.ToList();
            BuildNav();
            ApplyFilter();
            SelectedProject = Projects.FirstOrDefault(p => p.Folder == selected);
            if (detail is not null) DetailProject = _all.FirstOrDefault(p => p.Folder == detail);
            StatusMessage = $"{_all.Count} proje yüklendi";
            _ = LoadThumbnailsAsync(list);
            _ = UpdateRunningAsync();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            StatusMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async Task LoadThumbnailsAsync(IEnumerable<ProjectEntry> list)
    {
        var width = ThumbWidth;
        await Parallel.ForEachAsync(list.Where(p => p.ThumbnailPath is not null),
            new ParallelOptions { MaxDegreeOfParallelism = 4 },
            (p, _) =>
            {
                p.Thumbnail = ImageLoader.Load(p.ThumbnailPath!, width);
                return ValueTask.CompletedTask;
            });
    }

    public async Task CheckToolchainsAsync()
    {
        var result = await Task.Run(SystemStatus.CheckToolchains);
        Toolchains.Clear();
        foreach (var t in result) Toolchains.Add(t);
    }

    public async Task UpdateRunningAsync()
    {
        var snapshot = _all.ToList();
        var running = await Task.Run(() => SystemStatus.RunningFolders(snapshot));
        foreach (var p in snapshot) p.IsRunning = running.Contains(p.Folder);
        var names = snapshot.Where(p => p.IsRunning).Select(p => p.Name).ToList();
        RunningText = names.Count == 0 ? "Çalışan uygulama yok"
            : names.Count == 1 ? $"Çalışıyor: {names[0]}"
            : $"{names.Count} uygulama çalışıyor";
    }

    private void BuildNav()
    {
        var keep = (SelectedNav?.Kind, SelectedNav?.Value);
        NavItems.Clear();
        NavItems.Add(new NavItem { Label = "Tüm projeler", Kind = ScopeKind.All, Glyph = "" });
        NavItems.Add(new NavItem { Label = "Favoriler", Kind = ScopeKind.Favorites, Glyph = "" });
        NavItems.Add(new NavItem { Label = "Son kullanılanlar", Kind = ScopeKind.Recent, Glyph = "" });

        NavItems.Add(new NavItem { Label = "TEKNOLOJİ", Kind = ScopeKind.Header });
        foreach (var g in _all.GroupBy(p => p.Stack).OrderBy(g => g.Key))
            NavItems.Add(new NavItem { Label = g.First().StackLabel, Kind = ScopeKind.Stack, Value = g.Key.ToString(), Color = g.First().StackColor });

        var cats = _all.Where(p => p.Category is not null)
            .GroupBy(p => TurkishText.Fold(p.Category!)).Select(g => g.Select(p => p.Category!).Min(StringComparer.Ordinal)!) // "Verimlilik" > "verimlilik"
            .OrderBy(c => c, StringComparer.Create(new System.Globalization.CultureInfo("tr-TR"), true)).ToList();
        if (cats.Count > 0)
        {
            NavItems.Add(new NavItem { Label = "KATEGORİ", Kind = ScopeKind.Header });
            foreach (var c in cats)
                NavItems.Add(new NavItem { Label = c, Kind = ScopeKind.Category, Value = c, Glyph = "" });
        }

        UpdateCounts();
        SelectedNav = NavItems.FirstOrDefault(n => n.Kind == keep.Item1 && n.Value == keep.Item2) ?? NavItems[0];
    }

    private void UpdateCounts()
    {
        foreach (var n in NavItems.Where(n => !n.IsHeader))
            n.Count = ProjectFilter.Apply(_all, n.Kind, n.Value, ExeFilter.All, null, _state.Recent).Count();
    }

    public void ApplyFilter()
    {
        var nav = SelectedNav;
        var items = ProjectFilter.Apply(_all, nav?.Kind ?? ScopeKind.All, nav?.Value, ExeFilter, SearchText, _state.Recent).ToList();
        var selected = SelectedProject;

        // Ayni sonuc kumesi icin koleksiyonu yeniden kurma (kartlar ve resimleri yeniden olusmasin).
        if (!items.SequenceEqual(Projects))
        {
            Projects.Clear();
            foreach (var p in items) Projects.Add(p);
        }
        SelectedProject = selected is not null && Projects.Contains(selected) ? selected : null;

        ResultText = items.Count == _all.Count ? $"{_all.Count} proje" : $"{items.Count} / {_all.Count} proje";
    }

    // --- Detay ----------------------------------------------------------------

    [RelayCommand]
    private void OpenDetail(ProjectEntry? p)
    {
        p ??= SelectedProject;
        if (p is null) return;
        SelectedProject = p;
        DetailProject = p;
    }

    [RelayCommand]
    private void CloseDetail() => DetailProject = null;

    partial void OnDetailProjectChanged(ProjectEntry? value)
    {
        DetailShots.Clear();
        DetailImage = null;
        DetailReadme = null;
        SelectedShot = null;
        if (value is null) return;

        foreach (var s in value.Screenshots) DetailShots.Add(new ScreenshotItem(s));
        SelectedShot = DetailShots.FirstOrDefault();
        _ = LoadDetailExtrasAsync(value);
    }

    private async Task LoadDetailExtrasAsync(ProjectEntry p)
    {
        var shots = DetailShots.ToList();
        var readme = await Task.Run(() =>
        {
            foreach (var s in shots) s.Thumb = ImageLoader.Load(s.Path, 240);
            return ProjectCatalogService.ReadSummary(p.ReadmePath);
        });
        if (DetailProject == p) DetailReadme = readme;
    }

    partial void OnSelectedShotChanged(ScreenshotItem? value) => _ = LoadDetailImageAsync(value);

    private async Task LoadDetailImageAsync(ScreenshotItem? shot)
    {
        var img = await ImageLoader.LoadAsync(shot?.Path, DetailImageWidth);
        if (SelectedShot == shot) DetailImage = img;
    }

    // --- Eylemler -------------------------------------------------------------

    private ProjectEntry? Target(ProjectEntry? p) => p ?? DetailProject ?? SelectedProject;

    private void Act(ProjectEntry? p, Func<ProjectEntry, ProcessStartInfo> make, string done, bool remember)
    {
        if (Target(p) is not { } project) return;
        try
        {
            _start(make(project));
            StatusMessage = $"{done}: {project.Name}";
            if (remember)
            {
                StateStore.Touch(_state, project.Folder);
                SaveState();
                UpdateCounts();
                if (SelectedNav?.Kind == ScopeKind.Recent) ApplyFilter();
            }
        }
        catch (Exception ex) when (ex is InvalidOperationException or IOException or System.ComponentModel.Win32Exception)
        {
            StatusMessage = ex.Message;
        }
    }

    [RelayCommand]
    private void Open(ProjectEntry? p) =>
        Act(p, x => ProjectLaunchService.Open(x, _root), Target(p)?.HasExe == true ? "Açıldı" : "Kaynaktan başlatıldı", true);

    [RelayCommand]
    private void RunSource(ProjectEntry? p) => Act(p, x => ProjectLaunchService.Source(x, _root), "Kaynaktan başlatıldı", true);

    [RelayCommand]
    private void Publish(ProjectEntry? p) => Act(p, x => ProjectLaunchService.Publish(x, _root), "Exe üretimi başladı", false);

    [RelayCommand]
    private void RunTests(ProjectEntry? p) => Act(p, ProjectLaunchService.Tests, "Testler başladı", false);

    [RelayCommand]
    private void OpenFolder(ProjectEntry? p) => Act(p, ProjectLaunchService.Folder, "Klasör açıldı", false);

    [RelayCommand]
    private void OpenReadme(ProjectEntry? p) => Act(p, ProjectLaunchService.Readme, "README açıldı", false);

    [RelayCommand]
    private void ToggleFavorite(ProjectEntry? p)
    {
        if (Target(p) is not { } project) return;
        project.IsFavorite = !project.IsFavorite;
        _state.Favorites.Remove(project.Folder);
        if (project.IsFavorite) _state.Favorites.Add(project.Folder);
        SaveState();
        UpdateCounts();
        if (SelectedNav?.Kind == ScopeKind.Favorites) ApplyFilter();
        StatusMessage = project.IsFavorite ? $"Favorilere eklendi: {project.Name}" : $"Favorilerden çıkarıldı: {project.Name}";
    }

    private void SaveState()
    {
        try { _store.Save(_state); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            StatusMessage = "Durum kaydedilemedi: " + ex.Message;
        }
    }

    /// <summary>Esc: once detayi, sonra aramayi, sonra filtreleri temizler. Bir sey yaptiysa true.</summary>
    public bool ClearOne()
    {
        if (DetailProject is not null) { DetailProject = null; return true; }
        if (SearchText.Length > 0) { SearchText = ""; return true; }
        if (ExeFilter != ExeFilter.All || SelectedNav?.Kind != ScopeKind.All)
        {
            ExeFilter = ExeFilter.All;
            SelectedNav = NavItems.FirstOrDefault();
            return true;
        }
        return false;
    }
}
