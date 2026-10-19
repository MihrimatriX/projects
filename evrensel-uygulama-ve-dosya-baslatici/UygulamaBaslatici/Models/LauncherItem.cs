using System.Windows.Media;
using UygulamaBaslatici.Helpers;

namespace UygulamaBaslatici.Models;

public sealed class LauncherItem
{
    public string Name { get; }
    public string Path { get; }
    public string Type { get; }
    public string Group { get; }
    public int UsageCount { get; }

    private ImageSource? _icon;
    private bool _iconLoaded;

    public LauncherItem(string name, string path, string type, string group, int usageCount = 0)
    {
        Name = name;
        Path = path;
        Type = type;
        Group = group;
        UsageCount = usageCount;
    }

    public ImageSource? Icon
    {
        get
        {
            if (_iconLoaded) return _icon;
            _iconLoaded = true;
            if (Type is "App" or "Path")
                _icon = IconHelper.ExtractIconToImageSource(Path);
            return _icon;
        }
    }

    public bool HasCustomIcon => Icon != null;

    public string FallbackIcon => Type switch
    {
        "Command" => ">_",
        "WebSearch" => "🌐",
        _ => "▶"
    };

    public string? MetaText => Type switch
    {
        "App" when UsageCount > 0 => $"{UsageCount}×",
        "Command" => "↵",
        "WebSearch" => "web",
        "Path" => "aç",
        _ => null
    };

    public bool IsWebBadge => Type == "WebSearch";
}
