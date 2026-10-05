using System.IO;
namespace ProjeLauncher.Tests;

/// <summary>
/// Gecici sahte monorepo: 5 proje + dislanmasi gereken klasorler. launcher.ps1 sahtedir:
/// gercek proje calistirmaz, aldigi parametreleri launched.txt'ye yazar.
/// </summary>
public sealed class FakeRepo : IDisposable
{
    public const string Png1x1 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

    public string Root { get; } = Path.Combine(Path.GetTempPath(), "devprojects-test-" + Guid.NewGuid().ToString("N")[..8]);
    public string StateDir => Path.Combine(Root, ".state");
    public string LaunchedFile => Path.Combine(Root, "launched.txt");

    public FakeRepo()
    {
        Write("launcher.ps1", "param([string]$Exec, [string]$Publish)\r\n" +
                              "Set-Content -Path (Join-Path $PSScriptRoot 'launched.txt') -Value \"Exec=$Exec Publish=$Publish\"\r\n");

        // .NET: manifest (Turkce ad, etiket, kategori), iki ekran goruntusu, run + publish.
        Write(@"alpha-dotnet\Alpha\Alpha.csproj", "<Project />");
        Write(@"alpha-dotnet\README.md", "# Alpha README Basligi\n");
        Write(@"alpha-dotnet\run.ps1", "Write-Host fake");
        Write(@"alpha-dotnet\publish.ps1", "Write-Host fake");
        Write(@"alpha-dotnet\assets\manifest.json",
            """{ "name": "İstanbul Öğrenme Aracı", "description": "Işık hızında not alma.", "tags": ["Çeviri", "regex"], "category": "Verimlilik" }""");
        Png(@"alpha-dotnet\docs\ekran-detay.png");
        Png(@"alpha-dotnet\docs\ekran.png");

        // Flutter: README'den ad + giris + ozellikler, dist altinda exe.
        Write(@"beta-flutter\pubspec.yaml", "name: beta");
        Write(@"beta-flutter\run.ps1", "Write-Host fake");
        Write(@"beta-flutter\README.md",
            "# Beta Takvim\n\n![Ekran](docs/ekran.png)\n\nGünlük **plan** ve [hatırlatıcı](x.md) aracı.\nİkinci satır.\n\n## Özellikler\n\n- Ay görünümü\n- `Bildirim`\n\n## Kurulum\n\n- bu madde sayilmaz\n");
        Write(@"dist\beta-flutter\Beta.exe", "");

        Write(@"gamma-electron\package.json", """{ "devDependencies": { "electron": "40.0.0" } }""");
        Write(@"gamma-electron\README.md", "# Gamma Masaüstü\n");
        Write(@"gamma-electron\assets\manifest.json", """{ "name": "Gamma Masaüstü", "category": "verimlilik" }""");

        // node_modules icindeki .csproj projeyi .NET yapmamali.
        Write(@"delta-node\package.json", """{ "dependencies": { "next": "16.0.0" } }""");
        Write(@"delta-node\node_modules\x\x.csproj", "<Project />");
        Write(@"delta-node\README.md", "# Delta Web\n");

        // Bozuk manifest: README basligina duser.
        Write(@"epsilon-py\main.py", "print(1)");
        Write(@"epsilon-py\README.md", "# Epsilon Python\n");
        Write(@"epsilon-py\assets\manifest.json", "{ bozuk");

        // Dislananlar
        Write(@".hidden\README.md", "# Gizli");
        Write(@"proje-launcher\README.md", "# Launcher");
        Directory.CreateDirectory(Path.Combine(Root, "bos-klasor"));
    }

    public string Write(string rel, string content)
    {
        var path = Path.Combine(Root, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
        return path;
    }

    private void Png(string rel)
    {
        var path = Path.Combine(Root, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllBytes(path, Convert.FromBase64String(Png1x1));
    }

    public void Dispose()
    {
        try { Directory.Delete(Root, recursive: true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
    }
}
