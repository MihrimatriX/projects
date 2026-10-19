using System.IO.Compression;
using System.Net;
using System.Text.Json;
using CanliDuvarKagidi.Core.Host;
using CanliDuvarKagidi.Core.Models;
using CanliDuvarKagidi.Core.Services;

namespace CanliDuvarKagidi.Core.Tests;

public sealed class TempRoot : IDisposable
{
    public string Dir { get; } = Path.Combine(Path.GetTempPath(), "cdk-test-" + Guid.NewGuid().ToString("N"));
    public AppPaths Paths { get; }

    public TempRoot() => Paths = new AppPaths(Path.Combine(Dir, "data"));

    public void Dispose()
    {
        if (Directory.Exists(Dir))
            Directory.Delete(Dir, recursive: true);
    }

    /// <summary>manifest.json + wallpaper.png iceren bir paket zip'i olusturur.</summary>
    public string MakePackageZip(string name, string? title = "Paket")
    {
        var src = Path.Combine(Dir, "src-" + name);
        Directory.CreateDirectory(src);
        File.WriteAllBytes(Path.Combine(src, "wallpaper.png"), [1, 2, 3]);
        File.WriteAllText(Path.Combine(src, "manifest.json"),
            JsonSerializer.Serialize(new { title, type = "image", entry = "wallpaper.png" }));
        var zip = Path.Combine(Dir, "catalog", "assets", name + ".zip");
        Directory.CreateDirectory(Path.GetDirectoryName(zip)!);
        ZipFile.CreateFromDirectory(src, zip);
        return zip;
    }
}

public class SettingsTests
{
    [Fact]
    public void Save_then_load_roundtrips()
    {
        using var t = new TempRoot();
        var svc = new SettingsService(t.Paths);
        var s = new UserSettings { CatalogUrl = "http://x/index.json", RunAtStartup = true, PauseOnFullscreen = false };
        s.MonitorWallpapers["\\\\.\\DISPLAY1"] = "ornek";
        svc.Save(s);

        var loaded = svc.Load();
        Assert.Equal("http://x/index.json", loaded.CatalogUrl);
        Assert.True(loaded.RunAtStartup);
        Assert.False(loaded.PauseOnFullscreen);
        Assert.Equal("ornek", loaded.MonitorWallpapers["\\\\.\\DISPLAY1"]);
        Assert.False(File.Exists(t.Paths.SettingsFile + ".tmp"));
    }

    [Fact]
    public void Missing_file_gives_defaults()
    {
        using var t = new TempRoot();
        var s = new SettingsService(t.Paths).Load();
        Assert.Equal(CatalogUrlResolver.BundledToken, s.CatalogUrl);
        Assert.True(s.PauseOnFullscreen);
        Assert.Empty(s.MonitorWallpapers);
    }

    [Fact]
    public void Corrupt_file_gives_defaults_and_is_kept_aside()
    {
        using var t = new TempRoot();
        File.WriteAllText(t.Paths.SettingsFile, "{ bozuk json");

        var s = new SettingsService(t.Paths).Load();

        Assert.Equal(CatalogUrlResolver.BundledToken, s.CatalogUrl);
        Assert.True(File.Exists(t.Paths.SettingsFile + ".bozuk"));
        Assert.False(File.Exists(t.Paths.SettingsFile));
    }

    [Fact]
    public void Null_monitor_map_is_normalized()
    {
        using var t = new TempRoot();
        File.WriteAllText(t.Paths.SettingsFile, """{"MonitorWallpapers": null}""");
        Assert.NotNull(new SettingsService(t.Paths).Load().MonitorWallpapers);
    }
}

public class InstalledWallpaperTests
{
    [Theory]
    [InlineData("..")]
    [InlineData(".")]
    [InlineData("..\\..\\windows")]
    [InlineData("a/b")]
    [InlineData("")]
    [InlineData("c:")]
    public void Rejects_ids_that_escape_installed_dir(string id)
    {
        using var t = new TempRoot();
        Assert.Throws<InvalidOperationException>(() => new InstalledWallpaperService(t.Paths).GetPackagePath(id));
    }

    [Fact]
    public void Import_image_creates_listed_package_and_uninstall_removes_it()
    {
        using var t = new TempRoot();
        var svc = new InstalledWallpaperService(t.Paths);
        var file = Path.Combine(t.Dir, "Güzel Manzara Şehir.JPG");
        File.WriteAllBytes(file, [9, 9, 9]);

        var m = svc.ImportFile(file);

        Assert.Equal("yerel-guzel-manzara-sehir", m.Id);
        Assert.Equal("Güzel Manzara Şehir", m.Title);
        Assert.Equal(WallpaperType.Image, m.WallpaperType);
        Assert.True(File.Exists(m.ResolveEntryPath(svc.GetPackagePath(m.Id))));
        Assert.True(svc.IsInstalled(m.Id));
        Assert.Equal(m.Id, Assert.Single(svc.ListInstalled()).Id);
        Assert.Equal("wallpaper.jpg", svc.LoadManifest(m.Id)!.Entry);

        svc.Uninstall(m.Id);
        Assert.False(svc.IsInstalled(m.Id));
        Assert.Empty(svc.ListInstalled());
    }

    [Fact]
    public void Import_same_name_twice_gets_unique_ids()
    {
        using var t = new TempRoot();
        var svc = new InstalledWallpaperService(t.Paths);
        var file = Path.Combine(t.Dir, "klip.mp4");
        File.WriteAllBytes(file, [1]);

        var a = svc.ImportFile(file);
        var b = svc.ImportFile(file);

        Assert.Equal("yerel-klip", a.Id);
        Assert.Equal("yerel-klip-2", b.Id);
        Assert.Equal(WallpaperType.Video, b.WallpaperType);
        Assert.Equal(2, svc.ListInstalled().Count);
    }

    [Fact]
    public void Import_rejects_unsupported_and_missing_files()
    {
        using var t = new TempRoot();
        var svc = new InstalledWallpaperService(t.Paths);
        var txt = Path.Combine(t.Dir, "not.txt");
        File.WriteAllText(txt, "x");

        Assert.Throws<InvalidOperationException>(() => svc.ImportFile(txt));
        Assert.Throws<FileNotFoundException>(() => svc.ImportFile(Path.Combine(t.Dir, "yok.png")));
        Assert.Empty(svc.ListInstalled());
    }

    [Fact]
    public void Corrupt_manifest_is_skipped_in_listing()
    {
        using var t = new TempRoot();
        var dir = Path.Combine(t.Paths.Installed, "bozuk");
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "manifest.json"), "{{{");
        Assert.Empty(new InstalledWallpaperService(t.Paths).ListInstalled());
    }
}

public class CatalogTests
{
    private static string WriteIndex(TempRoot t, params object[] entries)
    {
        var index = Path.Combine(t.Dir, "catalog", "index.json");
        Directory.CreateDirectory(Path.GetDirectoryName(index)!);
        File.WriteAllText(index, JsonSerializer.Serialize(new { version = "1.0.0", wallpapers = entries }));
        return index;
    }

    [Fact]
    public async Task Local_catalog_fetch_and_install()
    {
        using var t = new TempRoot();
        t.MakePackageZip("deniz", title: "");
        var index = WriteIndex(t, new { id = "deniz", title = "Deniz", type = "image", version = "2.0.0", packageUrl = "assets/deniz.zip" });
        var installed = new InstalledWallpaperService(t.Paths);
        var catalog = new CatalogService(new HttpClient(), t.Paths, installed);

        var idx = await catalog.FetchIndexAsync(index);
        var entry = Assert.Single(idx.Wallpapers);
        var m = await catalog.DownloadAndInstallAsync(entry, CatalogService.GetCatalogBaseUrl(index));

        Assert.Equal("deniz", m.Id);
        Assert.Equal("Deniz", m.Title); // bos baslik katalogdan doldurulur
        Assert.Equal("2.0.0", m.Version);
        Assert.True(installed.IsInstalled("deniz"));
        Assert.Empty(Directory.GetFiles(t.Paths.Cache, "*", SearchOption.AllDirectories)); // gecici cikarma temizlendi
    }

    [Fact]
    public async Task Missing_local_package_throws()
    {
        using var t = new TempRoot();
        var index = WriteIndex(t, new { id = "yok", title = "Yok", packageUrl = "assets/yok.zip" });
        var catalog = new CatalogService(new HttpClient(), t.Paths, new InstalledWallpaperService(t.Paths));
        var entry = Assert.Single((await catalog.FetchIndexAsync(index)).Wallpapers);
        await Assert.ThrowsAsync<FileNotFoundException>(() => catalog.DownloadAndInstallAsync(entry, index));
    }

    [Fact]
    public async Task Unsafe_catalog_id_is_rejected_before_install()
    {
        using var t = new TempRoot();
        var catalog = new CatalogService(new HttpClient(), t.Paths, new InstalledWallpaperService(t.Paths));
        var entry = new CatalogEntry { Id = "..\\..\\x", PackageUrl = "assets/x.zip" };
        await Assert.ThrowsAsync<InvalidOperationException>(() => catalog.DownloadAndInstallAsync(entry, "http://h/"));
    }

    [Fact]
    public async Task Http_catalog_downloads_installs_and_leaves_no_zip_in_cache()
    {
        using var t = new TempRoot();
        var zipBytes = File.ReadAllBytes(t.MakePackageZip("orman", title: "Orman"));
        var http = new HttpClient(new FakeHandler(uri => uri.AbsolutePath switch
        {
            "/kat/index.json" => """{"wallpapers":[{"id":"orman","title":"Orman","packageUrl":"paket/orman.zip"}]}"""u8.ToArray(),
            "/kat/paket/orman.zip" => zipBytes,
            _ => null
        }));
        var installed = new InstalledWallpaperService(t.Paths);
        var catalog = new CatalogService(http, t.Paths, installed);
        const string url = "http://localhost:8080/kat/index.json";

        var entry = Assert.Single((await catalog.FetchIndexAsync(url)).Wallpapers);
        Assert.Equal("http://localhost:8080/kat/", CatalogService.GetCatalogBaseUrl(url));
        var m = await catalog.DownloadAndInstallAsync(entry, CatalogService.GetCatalogBaseUrl(url));

        Assert.Equal("Orman", m.Title);
        Assert.True(installed.IsInstalled("orman"));
        Assert.Empty(Directory.GetFiles(t.Paths.Cache, "*", SearchOption.AllDirectories));
    }

    [Fact]
    public void Bundled_token_and_empty_resolve_to_default()
    {
        var def = CatalogUrlResolver.GetDefaultCatalogUrl();
        Assert.Equal(def, CatalogUrlResolver.Resolve(null));
        Assert.Equal(def, CatalogUrlResolver.Resolve(" BUNDLED "));
        Assert.Equal("http://a/b.json", CatalogUrlResolver.Resolve(" http://a/b.json "));
        Assert.False(CatalogUrlResolver.TryGetLocalIndexPath("https://a/b.json", out _));
    }

    [Fact]
    public void Repo_bundled_catalog_is_valid_and_packages_exist()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CanliDuvarKagidi.sln")))
            dir = dir.Parent;
        Assert.NotNull(dir);

        var indexPath = Path.Combine(dir!.FullName, "catalog", "index.json");
        var index = JsonSerializer.Deserialize<CatalogIndex>(File.ReadAllText(indexPath))!;
        Assert.NotEmpty(index.Wallpapers);
        foreach (var e in index.Wallpapers)
            Assert.True(File.Exists(Path.Combine(dir.FullName, "catalog", e.PackageUrl)), e.PackageUrl);
    }

    private sealed class FakeHandler(Func<Uri, byte[]?> respond) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var body = respond(request.RequestUri!);
            return Task.FromResult(body == null
                ? new HttpResponseMessage(HttpStatusCode.NotFound)
                : new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(body) });
        }
    }
}

public class ModelAndFirstRunTests
{
    [Theory]
    [InlineData("video", WallpaperType.Video)]
    [InlineData("WEB", WallpaperType.Web)]
    [InlineData("image", WallpaperType.Image)]
    [InlineData("bilinmeyen", WallpaperType.Image)]
    public void Manifest_type_mapping(string type, WallpaperType expected) =>
        Assert.Equal(expected, new WallpaperManifest { Type = type }.WallpaperType);

    [Fact]
    public void First_run_flag()
    {
        using var t = new TempRoot();
        var fr = new FirstRunService(t.Paths, new InstalledWallpaperService(t.Paths));
        Assert.True(fr.IsFirstRun());
        fr.MarkInitialized();
        Assert.False(fr.IsFirstRun());
    }

    [Fact]
    public void Data_dir_env_var_overrides_default_root()
    {
        using var t = new TempRoot();
        var custom = Path.Combine(t.Dir, "env-root");
        var old = Environment.GetEnvironmentVariable(AppPaths.DataDirEnvVar);
        try
        {
            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, custom);
            Assert.Equal(custom, new AppPaths().Root);
            Assert.True(Directory.Exists(Path.Combine(custom, "installed")));
        }
        finally
        {
            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, old);
        }
    }
}

public class SearchAndSettingTests
{
    private static readonly WallpaperManifest Sample = new()
    {
        Id = "x", Title = "Gün Batımı Şehir", Type = "video", Description = "Sakin bir akşam"
    };

    [Theory]
    [InlineData(null, true)]
    [InlineData("  ", true)]
    [InlineData("batımı", true)]
    [InlineData("BATIMI", true)]     // buyuk harf + Turkce I
    [InlineData("gun batimi", true)] // aksan duyarsiz
    [InlineData("video", true)]
    [InlineData("akşam", true)]      // aciklama
    [InlineData("görsel", false)]
    [InlineData("deniz", false)]
    public void Manifest_matches_search(string? query, bool expected) =>
        Assert.Equal(expected, Sample.Matches(query));

    [Fact]
    public void Type_label_is_turkish() =>
        Assert.Equal(["Görsel", "Video", "Web"], new[] { "image", "VIDEO", "web" }.Select(WallpaperManifest.TypeLabel));

    [Theory]
    [InlineData("bundled", true)]
    [InlineData("", true)]
    [InlineData("http://localhost:8080/index.json", true)]
    [InlineData("https://ornek.test/katalog/index.json", true)]
    [InlineData(@"C:\katalog\index.json", true)]
    [InlineData("file:///C:/katalog/index.json", true)]
    [InlineData("ftp://ornek.test/index.json", false)]
    [InlineData("katalog/index.json", false)]
    [InlineData("localhost:8080", false)]
    public void Catalog_url_setting_validation(string url, bool expected) =>
        Assert.Equal(expected, CatalogUrlResolver.IsValidSetting(url));
}

public class EngineTests
{
    // NoDesktopHost: gercek masaustune pencere gomulmez; motorun oturum/ayar/duraklatma mantigi test edilir
    private static (WallpaperEngineService Engine, NoDesktopPlayerFactory Players, SettingsService Settings, string WallpaperId)
        Create(TempRoot t)
    {
        var settings = new SettingsService(t.Paths);
        settings.Save(new UserSettings { PauseOnFullscreen = false }); // zamanlayici on plandaki pencereye gore duraklatmasin
        var installed = new InstalledWallpaperService(t.Paths);
        var file = Path.Combine(t.Dir, "Deniz.png");
        File.WriteAllBytes(file, [1, 2, 3]);
        var id = installed.ImportFile(file).Id;
        var players = new NoDesktopPlayerFactory();
        var engine = new WallpaperEngineService(players, installed, settings, new FullscreenDetectionService(),
            m => new CanliDuvarKagidi.Core.Host.NoDesktopHost(m));
        return (engine, players, settings, id);
    }

    [Fact]
    public async Task Apply_records_session_and_settings_then_remove_clears_them()
    {
        using var t = new TempRoot();
        var (engine, players, settings, id) = Create(t);
        using var _ = engine;
        var monitor = MonitorService.GetMonitors()[0].Id;
        var changes = 0;
        engine.SessionsChanged += (_, _) => changes++;

        await engine.ApplyWallpaperAsync(monitor, id);

        Assert.Equal(id, engine.GetActiveAssignments()[monitor]);
        Assert.Equal(id, settings.Load().MonitorWallpapers[monitor]);
        Assert.True(Assert.Single(players.Created).IsPlaying);

        await engine.RemoveWallpaperAsync(monitor);
        Assert.Empty(engine.GetActiveAssignments());
        Assert.Empty(settings.Load().MonitorWallpapers);
        Assert.True(players.Created[0].IsDisposed);
        Assert.Equal(2, changes);
    }

    [Fact]
    public async Task User_pause_pauses_existing_and_new_players()
    {
        using var t = new TempRoot();
        var (engine, players, _, id) = Create(t);
        using var _ = engine;
        var monitor = MonitorService.GetMonitors()[0].Id;
        await engine.ApplyWallpaperAsync(monitor, id);

        engine.IsUserPaused = true;
        Assert.False(players.Created[0].IsPlaying);

        await engine.ApplyWallpaperAsync(monitor, id); // yeniden uygulama duraklatilmis baslar
        Assert.True(players.Created[0].IsDisposed);
        Assert.False(players.Created[1].IsPlaying);

        engine.IsUserPaused = false;
        Assert.True(players.Created[1].IsPlaying);
    }

    [Fact]
    public async Task Apply_unknown_wallpaper_throws_and_leaves_no_session()
    {
        using var t = new TempRoot();
        var (engine, _, _, _) = Create(t);
        using var _ = engine;
        var monitor = MonitorService.GetMonitors()[0].Id;
        await Assert.ThrowsAsync<InvalidOperationException>(() => engine.ApplyWallpaperAsync(monitor, "yok"));
        Assert.Empty(engine.GetActiveAssignments());
    }
}
