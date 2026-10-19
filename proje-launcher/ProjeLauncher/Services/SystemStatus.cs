using System.Diagnostics;
using System.Text.RegularExpressions;
using ProjeLauncher.Models;

namespace ProjeLauncher.Services;

public sealed record ToolStatus(string Name, bool Ok, string Hint)
{
    public string Label => $"{Name}: {(Ok ? "kurulu" : "yok")}";
}

/// <summary>Arac zinciri (launcher.ps1 -Doctor ile ayni denetimler) ve calisan proje tespiti.</summary>
public static class SystemStatus
{
    public static IReadOnlyList<ToolStatus> CheckToolchains() =>
    [
        new(".NET 10 SDK", DotnetSdkOk(), "winget install Microsoft.DotNet.SDK.10"),
        new("Flutter", OnPath("flutter") is not null || File.Exists(@"C:\flutter\bin\flutter.bat") ||
            File.Exists(Path.Combine(LocalAppData, @"flutter\bin\flutter.bat")), "docs.flutter.dev/get-started/install/windows"),
        new("Python", FindPython() is not null, "winget install Python.Python.3.13"),
        new("Node.js", OnPath("node") is not null, "winget install OpenJS.NodeJS.LTS"),
    ];

    private static string LocalAppData => Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

    private static bool DotnetSdkOk()
    {
        if (OnPath("dotnet") is not { } dotnet) return false;
        try
        {
            using var p = Process.Start(new ProcessStartInfo(dotnet, "--list-sdks")
            { RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true })!;
            var output = p.StandardOutput.ReadToEnd();
            p.WaitForExit(5000);
            return Regex.IsMatch(output, @"^1\d\.", RegexOptions.Multiline);
        }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException) { return false; }
    }

    private static string? FindPython()
    {
        foreach (var v in new[] { "314", "313", "312", "311" })
        {
            var p = Path.Combine(LocalAppData, $@"Programs\Python\Python{v}\python.exe");
            if (File.Exists(p)) return p;
        }
        // WindowsApps altindaki python, Microsoft Store yonlendirmesidir; gercek Python degil.
        return OnPath("py") ?? new[] { "python3", "python" }.Select(OnPath)
            .FirstOrDefault(c => c is not null && !c.Contains("WindowsApps", StringComparison.OrdinalIgnoreCase));
    }

    internal static string? OnPath(string name)
    {
        var exts = (Environment.GetEnvironmentVariable("PATHEXT") ?? ".EXE;.CMD;.BAT").Split(';', StringSplitOptions.RemoveEmptyEntries);
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries))
            foreach (var ext in exts)
            {
                try
                {
                    var f = Path.Combine(dir.Trim('"'), name + ext);
                    if (File.Exists(f)) return f;
                }
                catch (ArgumentException) { }
            }
        return null;
    }

    /// <summary>
    /// Exe'si dist\&lt;klasor&gt;\ altindan calisan projeler.
    /// ponytail: sureci exe adiyla arar (40 ucuz sorgu); dist altindan farkli adla baslayan yardimci surecler sayilmaz.
    /// </summary>
    public static HashSet<string> RunningFolders(IEnumerable<ProjectEntry> projects)
    {
        var running = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var p in projects)
        {
            if (p.ExePath is null) continue;
            foreach (var proc in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(p.ExePath)))
            {
                using (proc)
                {
                    try
                    {
                        var path = proc.MainModule?.FileName;
                        if (path is not null && path.StartsWith(p.DistDir + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                            running.Add(p.Folder);
                    }
                    catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException) { }
                }
            }
        }
        return running;
    }
}
