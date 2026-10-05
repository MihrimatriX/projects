using System.Text.Json;

namespace ProjeLauncher.Services;

public sealed class LauncherState
{
    public List<string> Favorites { get; set; } = [];
    /// <summary>Son kullanilan klasorler, en yeni basta.</summary>
    public List<string> Recent { get; set; } = [];
}

/// <summary>
/// Favoriler + son kullanilanlar: %LOCALAPPDATA%\DevProjects\state.json
/// (DEVPROJECTS_STATE_DIR ile degistirilebilir; testler gecici klasor kullanir).
/// </summary>
public sealed class StateStore(string? dir = null)
{
    public const int MaxRecent = 10;
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public string FilePath { get; } = Path.Combine(dir ?? DefaultDir(), "state.json");

    private static string DefaultDir() =>
        Environment.GetEnvironmentVariable("DEVPROJECTS_STATE_DIR") is { Length: > 0 } env ? env
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DevProjects");

    /// <summary>Dosya yoksa ya da bozuksa bos durum doner (bozuk dosya .bad olarak saklanir).</summary>
    public LauncherState Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return new();
            var s = JsonSerializer.Deserialize<LauncherState>(File.ReadAllText(FilePath), Json) ?? new();
            s.Favorites = s.Favorites?.Where(f => !string.IsNullOrWhiteSpace(f)).Distinct().ToList() ?? [];
            s.Recent = s.Recent?.Where(f => !string.IsNullOrWhiteSpace(f)).Distinct().Take(MaxRecent).ToList() ?? [];
            return s;
        }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            try { File.Copy(FilePath, FilePath + ".bad", overwrite: true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            return new();
        }
    }

    /// <summary>Atomik yazim: gecici dosyaya yaz, sonra uzerine tasi (yarim yazilmis state.json kalmaz).</summary>
    public void Save(LauncherState state)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        var tmp = FilePath + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(state, Json));
        File.Move(tmp, FilePath, overwrite: true);
    }

    public static void Touch(LauncherState state, string folder)
    {
        state.Recent.Remove(folder);
        state.Recent.Insert(0, folder);
        if (state.Recent.Count > MaxRecent) state.Recent.RemoveRange(MaxRecent, state.Recent.Count - MaxRecent);
    }
}
