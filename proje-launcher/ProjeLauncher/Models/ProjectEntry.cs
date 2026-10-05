using System.Globalization;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using ProjeLauncher.Services;

namespace ProjeLauncher.Models;

public sealed partial class ProjectEntry : ObservableObject
{
    public required string Folder { get; init; }
    public required string Name { get; init; }
    public required string Path { get; init; }
    public required ProjectStack Stack { get; init; }
    public string? Description { get; init; }
    public string[] Tags { get; init; } = [];
    public string? Category { get; init; }
    public string ReadmePath { get; init; } = "";
    /// <summary>run.ps1 (kaynaktan calistirma, -Check testleri).</summary>
    public string? RunScript { get; init; }
    public string? PublishScript { get; init; }
    /// <summary>&lt;repo&gt;\dist\&lt;klasor&gt;\ (publish.ps1 ciktisi).</summary>
    public string DistDir { get; init; } = "";
    public string? ExePath { get; init; }
    /// <summary>docs\ekran*.png; ekran.png ilk sirada.</summary>
    public string[] Screenshots { get; init; } = [];

    [ObservableProperty] private bool _isFavorite;
    [ObservableProperty] private bool _isRunning;
    [ObservableProperty] private ImageSource? _thumbnail;

    public bool HasExe => ExePath is not null;
    public bool HasRunScript => RunScript is not null;
    public bool HasPublish => PublishScript is not null;
    public bool CanLaunch => ExePath is not null || RunScript is not null;
    public string? ThumbnailPath => Screenshots.Length > 0 ? Screenshots[0] : null;
    public string StackLabel => Stack switch
    {
        ProjectStack.Dotnet => "C# / .NET",
        ProjectStack.Flutter => "Flutter",
        ProjectStack.Python => "Python",
        ProjectStack.Node => "Next.js / Web",
        ProjectStack.Electron => "Electron",
        _ => "Diğer"
    };
    public string StackColor => Stack switch
    {
        ProjectStack.Dotnet => "#512BD4",
        ProjectStack.Flutter => "#0468D7",
        ProjectStack.Python => "#306998",
        ProjectStack.Node => "#5B6472",
        ProjectStack.Electron => "#2B7489",
        _ => "#52525B"
    };
    public string ExeStatus => ExePath is not null ? "Exe hazır" : "Exe yok";
    public string ExeRelative => ExePath is not null ? $@"dist\{Folder}\{System.IO.Path.GetFileName(ExePath)}" : "Henüz üretilmedi";
    public string TagsText => string.Join(", ", Tags);

    /// <summary>Kartta yer tutucu: ilk iki kelimenin bas harfleri.</summary>
    public string Initials
    {
        get
        {
            var tr = CultureInfo.GetCultureInfo("tr-TR");
            var words = Name.Split([' ', '-', '_'], StringSplitOptions.RemoveEmptyEntries)
                .Where(w => char.IsLetterOrDigit(w[0])).Take(2).Select(w => w[..1].ToUpper(tr));
            var s = string.Concat(words);
            return s.Length > 0 ? s : "?";
        }
    }

    /// <summary>Arama icin onceden katlanmis metin (ad, aciklama, etiketler, klasor, kategori, yigin).</summary>
    public string SearchKey => _searchKey ??= TurkishText.Fold(
        string.Join(' ', [Name, Description ?? "", .. Tags, Folder, Category ?? "", StackLabel]));
    private string? _searchKey;
}
