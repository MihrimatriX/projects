namespace ProjeLauncher.Services;

public static class RepoRoot
{
    /// <summary>
    /// DEVPROJECTS_ROOT (testler sahte kok verir) ya da exe konumundan yukari cikarak
    /// .devprojects-root veya launcher.ps1 iceren ilk klasor.
    /// </summary>
    public static string Find()
    {
        if (Environment.GetEnvironmentVariable("DEVPROJECTS_ROOT") is { Length: > 0 } env)
            return Directory.Exists(env) ? Path.GetFullPath(env)
                : throw new DirectoryNotFoundException("DEVPROJECTS_ROOT klasoru yok: " + env);

        var starts = new[] { AppContext.BaseDirectory, Path.GetDirectoryName(Environment.ProcessPath) ?? "" };
        foreach (var start in starts.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(start)) continue;
            for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
                if (IsRepoRoot(dir.FullName)) return dir.FullName;
        }

        throw new DirectoryNotFoundException("Repo kökü bulunamadı (.devprojects-root veya launcher.ps1 içeren klasör).");
    }

    private static bool IsRepoRoot(string path) =>
        File.Exists(Path.Combine(path, ".devprojects-root")) ||
        File.Exists(Path.Combine(path, "launcher.ps1"));
}
