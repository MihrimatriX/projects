using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Host;
using CanliDuvarKagidi.Core.Services;
using CanliDuvarKagidi.Players;

namespace CanliDuvarKagidi_Shell.Services;

public static class AppServices
{
    private static bool _initialized;

    /// <summary>
    /// CANLI_DUVAR_UITEST=1: arayuz testleri icin. Duvar kagidi masaustune gomulmez (kullanicinin
    /// masaustu degismez) ve "Windows baslangicinda calistir" kayit defterine yazilmaz.
    /// </summary>
    public static bool UiTestMode { get; } = Environment.GetEnvironmentVariable("CANLI_DUVAR_UITEST") == "1";

    public static AppPaths Paths { get; private set; } = null!;
    public static SettingsService Settings { get; private set; } = null!;
    public static InstalledWallpaperService Installed { get; private set; } = null!;
    public static CatalogService Catalog { get; private set; } = null!;
    public static FirstRunService FirstRun { get; private set; } = null!;
    public static WallpaperEngineService Engine { get; private set; } = null!;
    public static ExplorerReconnectService ExplorerReconnect { get; private set; } = null!;
    public static HttpClient Http { get; private set; } = null!;

    // Ilk acilista ornekler arka planda kurulurken sayfa zaten yuklenmis olabilir; bitince yenilensin
    public static event Action? StartupCompleted;

    public static void Initialize()
    {
        if (_initialized)
            return;

        Paths = new AppPaths();
        Settings = new SettingsService(Paths);
        Installed = new InstalledWallpaperService(Paths);
        Http = new HttpClient { Timeout = TimeSpan.FromMinutes(5) };

        IWallpaperPlayerFactory playerFactory = UiTestMode ? new NoDesktopPlayerFactory() : new WallpaperPlayerFactory();
        var fullscreen = new FullscreenDetectionService();
        Catalog = new CatalogService(Http, Paths, Installed);
        FirstRun = new FirstRunService(Paths, Installed);
        Engine = new WallpaperEngineService(playerFactory, Installed, Settings, fullscreen,
            UiTestMode ? m => new NoDesktopHost(m) : null);
        ExplorerReconnect = new ExplorerReconnectService(Engine);

        _initialized = true;
    }

    public static async Task RunStartupAsync()
    {
        if (FirstRun.IsFirstRun())
        {
            await FirstRun.InstallBundledSamplesAsync();
            FirstRun.MarkInitialized();

            var settings = Settings.Load();
            if (string.IsNullOrWhiteSpace(settings.CatalogUrl) ||
                settings.CatalogUrl == CatalogUrlResolver.BundledToken)
            {
                settings.CatalogUrl = CatalogUrlResolver.BundledToken;
                Settings.Save(settings);
            }
        }

        await Engine.RestoreSavedWallpapersAsync();
        StartupCompleted?.Invoke();
    }
}
