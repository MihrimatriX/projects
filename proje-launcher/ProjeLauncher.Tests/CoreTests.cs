using System.IO;
using System.Diagnostics;
using ProjeLauncher.Models;
using ProjeLauncher.Services;
using ProjeLauncher.ViewModels;
using Xunit;

namespace ProjeLauncher.Tests;

public sealed class CatalogTests : IDisposable
{
    private readonly FakeRepo _repo = new();
    private readonly IReadOnlyList<ProjectEntry> _all;

    public CatalogTests() => _all = ProjectCatalogService.Load(_repo.Root);
    public void Dispose() => _repo.Dispose();

    private ProjectEntry P(string folder) => _all.Single(p => p.Folder == folder);

    [Fact]
    public void Loads_only_real_projects_sorted_by_turkish_name()
    {
        Assert.Equal(["beta-flutter", "delta-node", "epsilon-py", "gamma-electron", "alpha-dotnet"], _all.Select(p => p.Folder));
    }

    [Fact]
    public void Detects_stacks()
    {
        Assert.Equal(ProjectStack.Dotnet, P("alpha-dotnet").Stack);
        Assert.Equal(ProjectStack.Flutter, P("beta-flutter").Stack);
        Assert.Equal(ProjectStack.Electron, P("gamma-electron").Stack);
        Assert.Equal(ProjectStack.Node, P("delta-node").Stack);
        Assert.Equal(ProjectStack.Python, P("epsilon-py").Stack);
    }

    [Fact]
    public void Reads_manifest_and_falls_back_to_readme()
    {
        var a = P("alpha-dotnet");
        Assert.Equal("İstanbul Öğrenme Aracı", a.Name);
        Assert.Equal("Işık hızında not alma.", a.Description);
        Assert.Equal(["Çeviri", "regex"], a.Tags);
        Assert.Equal("Verimlilik", a.Category);
        Assert.Equal("Epsilon Python", P("epsilon-py").Name); // bozuk manifest
        Assert.Equal("Günlük plan ve hatırlatıcı aracı. İkinci satır.", P("beta-flutter").Description);
    }

    [Fact]
    public void Detects_exe_scripts_and_screenshots()
    {
        var b = P("beta-flutter");
        Assert.True(b.HasExe);
        Assert.Equal(@"dist\beta-flutter\Beta.exe", b.ExeRelative);
        Assert.False(P("alpha-dotnet").HasExe);
        Assert.True(P("alpha-dotnet").HasPublish);
        Assert.False(P("gamma-electron").CanLaunch);

        var shots = P("alpha-dotnet").Screenshots.Select(Path.GetFileName);
        Assert.Equal(["ekran.png", "ekran-detay.png"], shots);
        Assert.Null(b.ThumbnailPath);
    }

    [Fact]
    public void Readme_summary_has_intro_and_features_only_from_features_section()
    {
        var s = ProjectCatalogService.ReadSummary(P("beta-flutter").ReadmePath);
        Assert.Equal("Günlük plan ve hatırlatıcı aracı. İkinci satır.", s.Intro);
        Assert.Equal(["Ay görünümü", "Bildirim"], s.Features);
        Assert.Equal("", ProjectCatalogService.ReadSummary(Path.Combine(_repo.Root, "yok.md")).Intro);
    }

    [Fact]
    public void Initials_use_turkish_upper_case()
    {
        Assert.Equal("İÖ", P("alpha-dotnet").Initials);
        Assert.Equal("BT", P("beta-flutter").Initials);
    }
}

public sealed class SearchTests : IDisposable
{
    private readonly FakeRepo _repo = new();
    private readonly IReadOnlyList<ProjectEntry> _all;

    public SearchTests() => _all = ProjectCatalogService.Load(_repo.Root);
    public void Dispose() => _repo.Dispose();

    private string[] Search(string q, ExeFilter exe = ExeFilter.All, ScopeKind scope = ScopeKind.All, string? value = null, IReadOnlyList<string>? recent = null) =>
        ProjectFilter.Apply(_all, scope, value, exe, q, recent ?? []).Select(p => p.Folder).ToArray();

    [Theory]
    [InlineData("İstanbul")]
    [InlineData("istanbul")]
    [InlineData("ISTANBUL")]
    [InlineData("ıstanbul")]
    [InlineData("ogrenme")]   // ASCII yazim Turkce harfleri bulur
    [InlineData("ÖĞRENME")]
    [InlineData("ISIK")]      // aciklama
    [InlineData("işık")]
    [InlineData("ceviri")]    // etiket
    [InlineData("REGEX")]
    [InlineData("alpha-dot")] // klasor
    [InlineData("verimlilik")] // kategori
    [InlineData("  istanbul   arac ")] // cok kelime = VE
    public void Turkish_insensitive_search_finds_alpha(string q) =>
        Assert.Contains("alpha-dotnet", Search(q));

    [Fact]
    public void Multiple_terms_must_all_match() => Assert.Empty(Search("istanbul flutter"));

    [Fact]
    public void Fold_maps_all_turkish_letters() =>
        Assert.Equal("iiiiogusc", TurkishText.Fold("İIıiÖĞÜŞÇ"));

    [Fact]
    public void Empty_query_returns_all() => Assert.Equal(5, Search("").Length);

    [Fact]
    public void Exe_filter()
    {
        Assert.Equal(["beta-flutter"], Search("", ExeFilter.HasExe));
        Assert.Equal(4, Search("", ExeFilter.NoExe).Length);
    }

    [Fact]
    public void Stack_category_favorite_and_recent_scopes()
    {
        Assert.Equal(["beta-flutter"], Search("", scope: ScopeKind.Stack, value: "Flutter"));
        // Kategori buyuk/kucuk harf duyarsiz gruplanir.
        Assert.Equal(["gamma-electron", "alpha-dotnet"], Search("", scope: ScopeKind.Category, value: "VERİMLİLİK"));
        _all.Single(p => p.Folder == "delta-node").IsFavorite = true;
        Assert.Equal(["delta-node"], Search("", scope: ScopeKind.Favorites));
        // Son kullanilanlar en yeni basta; silinmis proje atlanir.
        Assert.Equal(["epsilon-py", "alpha-dotnet"], Search("", scope: ScopeKind.Recent, recent: ["epsilon-py", "silinmis", "alpha-dotnet"]));
    }
}

public sealed class StateTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "devprojects-state-" + Guid.NewGuid().ToString("N")[..8]);
    public void Dispose() { try { Directory.Delete(_dir, true); } catch (IOException) { } }

    [Fact]
    public void Roundtrip_and_atomic_write()
    {
        var store = new StateStore(_dir);
        Assert.Empty(store.Load().Favorites); // dosya yok
        store.Save(new LauncherState { Favorites = ["a", "b"], Recent = ["c"] });
        var s = store.Load();
        Assert.Equal(["a", "b"], s.Favorites);
        Assert.Equal(["c"], s.Recent);
        Assert.False(File.Exists(store.FilePath + ".tmp"));
        store.Save(new LauncherState { Favorites = ["z"] }); // uzerine yazma
        Assert.Equal(["z"], store.Load().Favorites);
    }

    [Theory]
    [InlineData("{ bozuk")]
    [InlineData("")]
    [InlineData("null")]
    [InlineData("""{ "favorites": null, "recent": [null, "x", "x"] }""")]
    [InlineData("""{ "favorites": 5 }""")]
    public void Corrupt_file_is_tolerated(string content)
    {
        var store = new StateStore(_dir);
        Directory.CreateDirectory(_dir);
        File.WriteAllText(store.FilePath, content);
        var s = store.Load();
        Assert.NotNull(s.Favorites);
        Assert.True(s.Recent.Count <= 1);
        store.Save(s); // bozuk dosyadan sonra yazim calisir
    }

    [Fact]
    public void Touch_moves_to_front_and_caps()
    {
        var s = new LauncherState();
        for (var i = 0; i < 15; i++) StateStore.Touch(s, "p" + i);
        StateStore.Touch(s, "p10");
        Assert.Equal(StateStore.MaxRecent, s.Recent.Count);
        Assert.Equal(["p10", "p14", "p13"], s.Recent.Take(3));
        Assert.Equal(1, s.Recent.Count(r => r == "p10"));
    }
}

public sealed class LaunchTests : IDisposable
{
    private readonly FakeRepo _repo = new();
    private readonly IReadOnlyList<ProjectEntry> _all;
    public LaunchTests() => _all = ProjectCatalogService.Load(_repo.Root);
    public void Dispose() => _repo.Dispose();
    private ProjectEntry P(string folder) => _all.Single(p => p.Folder == folder);

    [Fact]
    public void Source_uses_launcher_exec_in_project_dir()
    {
        var psi = ProjectLaunchService.Source(P("alpha-dotnet"), _repo.Root);
        Assert.Equal("powershell.exe", psi.FileName);
        Assert.Equal(P("alpha-dotnet").Path, psi.WorkingDirectory);
        Assert.Equal(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", Path.Combine(_repo.Root, "launcher.ps1"), "-Exec", "alpha-dotnet"], psi.ArgumentList);
    }

    [Fact]
    public void Publish_and_tests_keep_console_open()
    {
        var pub = ProjectLaunchService.Publish(P("alpha-dotnet"), _repo.Root);
        Assert.Equal(["-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", Path.Combine(_repo.Root, "launcher.ps1"), "-Publish", "alpha-dotnet"], pub.ArgumentList);
        var t = ProjectLaunchService.Tests(P("beta-flutter"));
        Assert.Equal(["-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", P("beta-flutter").RunScript!, "-Check"], t.ArgumentList);
    }

    [Fact]
    public void Open_prefers_exe_and_missing_scripts_throw()
    {
        Assert.Equal(P("beta-flutter").ExePath, ProjectLaunchService.Open(P("beta-flutter"), _repo.Root).FileName);
        Assert.Equal("powershell.exe", ProjectLaunchService.Open(P("alpha-dotnet"), _repo.Root).FileName);
        Assert.Throws<InvalidOperationException>(() => ProjectLaunchService.Source(P("gamma-electron"), _repo.Root));
        Assert.Throws<InvalidOperationException>(() => ProjectLaunchService.Publish(P("beta-flutter"), _repo.Root));
        var noReadme = new ProjectEntry { Folder = "x", Name = "x", Path = _repo.Root, Stack = ProjectStack.Other, ReadmePath = Path.Combine(_repo.Root, "yok.md") };
        Assert.Throws<FileNotFoundException>(() => ProjectLaunchService.Readme(noReadme));
    }
}

// DEVPROJECTS_ROOT surec geneli: bu ortam degiskenini yalnizca bu sinif ayarlar.
public sealed class ViewModelTests : IDisposable
{
    private readonly FakeRepo _repo = new();
    public ViewModelTests() => Environment.SetEnvironmentVariable("DEVPROJECTS_ROOT", _repo.Root);
    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DEVPROJECTS_ROOT", null);
        _repo.Dispose();
    }

    [Fact]
    public async Task Launch_records_recent_and_favorites_persist()
    {
        var started = new List<ProcessStartInfo>();
        var store = new StateStore(_repo.StateDir);
        var vm = new MainViewModel(store, started.Add);
        await vm.RefreshAsync();
        Assert.Equal("5 proje", vm.ResultText);
        Assert.Contains(vm.NavItems, n => n.Kind == ScopeKind.Category && n.Label == "Verimlilik" && n.Count == 2);

        vm.SearchText = "ISIK";
        Assert.Equal("1 / 5 proje", vm.ResultText);
        var alpha = Assert.Single(vm.Projects);

        vm.OpenDetailCommand.Execute(alpha);
        Assert.Equal(2, vm.DetailShots.Count);
        vm.RunSourceCommand.Execute(null);
        Assert.Equal("-Exec", Assert.Single(started).ArgumentList[^2]);
        vm.ToggleFavoriteCommand.Execute(null);

        var saved = store.Load();
        Assert.Equal(["alpha-dotnet"], saved.Recent);
        Assert.Equal(["alpha-dotnet"], saved.Favorites);

        Assert.True(vm.ClearOne()); // detay kapanir
        Assert.Null(vm.DetailProject);
        Assert.True(vm.ClearOne()); // arama temizlenir
        Assert.Equal(5, vm.Projects.Count);

        vm.SelectedNav = vm.NavItems.Single(n => n.Kind == ScopeKind.Favorites);
        Assert.Equal("alpha-dotnet", Assert.Single(vm.Projects).Folder);
        vm.SelectedNav = vm.NavItems.First(n => n.IsHeader); // basliklar secilemez
        Assert.Equal(ScopeKind.Favorites, vm.SelectedNav!.Kind);
        Assert.True(vm.ClearOne()); // filtre sifirlanir
        Assert.Equal(ScopeKind.All, vm.SelectedNav!.Kind);
        Assert.False(vm.ClearOne());
    }

    [Fact]
    public async Task Launch_error_is_shown_not_thrown()
    {
        var vm = new MainViewModel(new StateStore(_repo.StateDir), _ => throw new System.ComponentModel.Win32Exception("bulunamadi"));
        await vm.RefreshAsync();
        vm.OpenCommand.Execute(vm.Projects.Single(p => p.Folder == "beta-flutter"));
        Assert.Equal("bulunamadi", vm.StatusMessage);
        Assert.Empty(new StateStore(_repo.StateDir).Load().Recent);
    }
}
