using System.Text.Json;
using CanliDuvarKagidi.Core.Host;
using CanliDuvarKagidi.Core.Models;
using CanliDuvarKagidi.Core.Services;
using CanliDuvarKagidi.Players;

static string FindRepoRoot()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir != null)
    {
        if (File.Exists(Path.Combine(dir.FullName, "CanliDuvarKagidi.sln")))
            return dir.FullName;
        dir = dir.Parent;
    }

    throw new InvalidOperationException("CanliDuvarKagidi.sln bulunamadi.");
}

Console.WriteLine("Diagnose: " + DesktopWorkerW.Diagnose());

var monitor = MonitorService.GetMonitors()[0];
Console.WriteLine($"Monitor: {monitor.Name} {monitor.Width}x{monitor.Height} @ ({monitor.X},{monitor.Y})");

var repo = FindRepoRoot();
var packageRoot = Path.Combine(repo, "catalog", "assets", "ornek-gorsel");
var manifestPath = Path.Combine(packageRoot, "manifest.json");
var manifest = JsonSerializer.Deserialize<WallpaperManifest>(File.ReadAllText(manifestPath))!;

var host = new DesktopWallpaperHost(monitor);
await host.AttachToDesktopAsync();
Console.WriteLine($"Host HWND: 0x{host.WindowHandle:X}");

var player = new ImagePlayer();
await player.AttachAsync(host.WindowHandle, monitor, manifest, packageRoot);
player.Play();

Console.WriteLine("OK — ornek gorsel 8 sn masaustunde. Kapatmak icin bekleyin...");
await Task.Delay(8000);

player.Dispose();
host.Dispose();
Console.WriteLine("Done.");
