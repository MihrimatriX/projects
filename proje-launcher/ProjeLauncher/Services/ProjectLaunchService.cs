using System.Diagnostics;
using ProjeLauncher.Models;

namespace ProjeLauncher.Services;

/// <summary>
/// Proje eylemleri icin ProcessStartInfo uretir (birim testlenir) ve baslatir.
/// Konsol isleri kok launcher.ps1 uzerinden yeni PowerShell penceresinde calisir.
/// </summary>
public static class ProjectLaunchService
{
    private static readonly string[] PsBase = ["-NoProfile", "-ExecutionPolicy", "Bypass"];

    /// <summary>Exe varsa exe, yoksa kaynaktan.</summary>
    public static ProcessStartInfo Open(ProjectEntry p, string root)
    {
        if (p.ExePath is null) return Source(p, root);
        return new ProcessStartInfo(p.ExePath) { WorkingDirectory = Path.GetDirectoryName(p.ExePath)!, UseShellExecute = true };
    }

    /// <summary>launcher.ps1 -Exec: arac zincirini denetler, hata olursa pencereyi acik tutar.</summary>
    public static ProcessStartInfo Source(ProjectEntry p, string root)
    {
        if (p.RunScript is null) throw new InvalidOperationException("Bu projede run.ps1 yok; README'ye bakın.");
        var launcher = Path.Combine(root, "launcher.ps1");
        return File.Exists(launcher)
            ? Ps(p.Path, false, "-File", launcher, "-Exec", p.Folder)
            : Ps(p.Path, true, "-File", p.RunScript);
    }

    /// <summary>launcher.ps1 -Publish: publish.ps1'i calistirir; pencere sonucu gostermek icin acik kalir.</summary>
    public static ProcessStartInfo Publish(ProjectEntry p, string root)
    {
        if (p.PublishScript is null) throw new InvalidOperationException("Bu projede publish.ps1 yok.");
        var launcher = Path.Combine(root, "launcher.ps1");
        return File.Exists(launcher)
            ? Ps(p.Path, true, "-File", launcher, "-Publish", p.Folder)
            : Ps(p.Path, true, "-File", p.PublishScript);
    }

    public static ProcessStartInfo Tests(ProjectEntry p)
    {
        if (p.RunScript is null) throw new InvalidOperationException("Bu projede run.ps1 yok.");
        return Ps(p.Path, true, "-File", p.RunScript, "-Check");
    }

    public static ProcessStartInfo Folder(ProjectEntry p) =>
        new("explorer.exe") { ArgumentList = { p.Path }, UseShellExecute = false };

    public static ProcessStartInfo Readme(ProjectEntry p) =>
        File.Exists(p.ReadmePath)
            ? new ProcessStartInfo(p.ReadmePath) { UseShellExecute = true }
            : throw new FileNotFoundException("README bulunamadı.", p.ReadmePath);

    public static void Start(ProcessStartInfo psi) => Process.Start(psi)?.Dispose();

    // GUI surecinden UseShellExecute=false ile baslatilan powershell.exe kendi yeni konsolunu alir.
    private static ProcessStartInfo Ps(string workDir, bool noExit, params string[] args)
    {
        var psi = new ProcessStartInfo("powershell.exe") { WorkingDirectory = workDir, UseShellExecute = false };
        foreach (var a in PsBase) psi.ArgumentList.Add(a);
        if (noExit) psi.ArgumentList.Add("-NoExit");
        foreach (var a in args) psi.ArgumentList.Add(a);
        return psi;
    }
}
