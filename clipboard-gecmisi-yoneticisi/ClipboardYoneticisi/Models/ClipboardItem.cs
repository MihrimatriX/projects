using System;
using System.IO;
using System.Linq;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ClipboardYoneticisi.Helpers;
using ClipboardYoneticisi.Services;

using CommunityToolkit.Mvvm.ComponentModel;

namespace ClipboardYoneticisi.Models;

public partial class ClipboardItem : ObservableObject
{
  private BitmapImage? _cachedImage;

  public int Id { get; }
  public string Type { get; }
  public string Content { get; }
  public DateTime Timestamp { get; }
  public TextCategory TextCategory { get; }
  public string? OcrText { get; }

  [ObservableProperty]
  private bool _isPinned;

  public ClipboardItem(int id, string type, string content, DateTime timestamp, bool isPinned, string? ocrText = null)
  {
    Id = id;
    Type = type;
    Content = content;
    Timestamp = timestamp;
    _isPinned = isPinned;
    OcrText = ocrText;

    var plainForClassify = type == "Html"
      ? HtmlClipboardHelper.ExtractPlainText(content)
      : content;
    TextCategory = type is "Text" or "Html"
      ? ContentClassifier.Classify(plainForClassify)
      : TextCategory.Plain;
  }

  public string BadgeLabel => Type switch
  {
    "Text" when TextCategory == TextCategory.Url => "URL",
    "Text" when TextCategory == TextCategory.Email => "E-posta",
    "Text" when TextCategory == TextCategory.Code => "Kod",
    "Html" => "HTML",
    "Text" => "Metin",
    "Image" => "Görsel",
    "File" => "Dosya",
    _ => "Diğer"
  };

  public Brush BadgeForeground => BadgeBrush(Type, TextCategory);

  public Brush BadgeBackground => BadgeBackgroundBrush(Type, TextCategory);

  public string FilterKey => Type switch
  {
    "Text" when TextCategory == TextCategory.Url => "Url",
    "Text" when TextCategory == TextCategory.Code => "Code",
    "Html" => "Text",
    "Text" => "Text",
    "Image" => "Image",
    "File" => "Text",
    _ => "Other"
  };

  public bool IsImage => Type == "Image";
  public bool HasOcrText => !string.IsNullOrWhiteSpace(OcrText);
  public string RelativeTime => RelativeTimeHelper.Format(Timestamp);

  public bool IsSensitiveHidden =>
    SettingsService.Instance.Settings.BlurSensitiveContent && GetPlainContent() is { } plain &&
    SensitiveContentDetector.LooksSensitive(plain);

  public string PreviewText
  {
    get
    {
      if (IsSensitiveHidden)
        return "Hassas içerik gizlendi";

      if (Type == "Text")
        return Truncate(Content.Replace("\r", "").Replace("\n", " ").Trim());

      if (Type == "Html")
        return Truncate(HtmlClipboardHelper.ExtractPlainText(Content));

      if (Type == "File")
      {
        var lines = Content.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length == 1)
          return Path.GetFileName(lines[0]);

        return $"{lines.Length} dosya: " +
               string.Join(", ", lines.Select(Path.GetFileName).Take(3)) +
               (lines.Length > 3 ? "…" : "");
      }

      if (Type == "Image")
        return HasOcrText ? Truncate(OcrText!) : "Ekran görüntüsü";

      return "Bilinmeyen içerik";
    }
  }

  public ImageSource? ImagePreview
  {
    get
    {
      if (Type != "Image" || !File.Exists(Content))
        return null;

      if (_cachedImage != null)
        return _cachedImage;

      try
      {
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        bitmap.UriSource = new Uri(Content);
        bitmap.DecodePixelWidth = 96;
        bitmap.EndInit();
        bitmap.Freeze();
        _cachedImage = bitmap;
        return _cachedImage;
      }
      catch (Exception ex)
      {
        System.Diagnostics.Debug.WriteLine($"Thumbnail load failed: {ex.Message}");
        return null;
      }
    }
  }

  private string? GetPlainContent()
  {
    if (Type == "Text") return Content;
    if (Type == "Html") return HtmlClipboardHelper.ExtractPlainText(Content);
    return null;
  }

  private static Brush BadgeBrush(string type, TextCategory category) => type switch
  {
    "Text" when category == TextCategory.Url => FrozenBrush("#89DCEB"),
    "Text" when category == TextCategory.Email => FrozenBrush("#A6E3A1"),
    "Text" when category == TextCategory.Code => FrozenBrush("#CBA6F7"),
    "Html" => FrozenBrush("#89B4FA"),
    "Text" => FrozenBrush("#A6E3A1"),
    "Image" => FrozenBrush("#F9E2AF"),
    "File" => FrozenBrush("#FAB387"),
    _ => FrozenBrush("#6C7086")
  };

  private static Brush BadgeBackgroundBrush(string type, TextCategory category) => type switch
  {
    "Text" when category == TextCategory.Url => FrozenBrush("#2689DCEB"),
    "Text" when category == TextCategory.Email => FrozenBrush("#26A6E3A1"),
    "Text" when category == TextCategory.Code => FrozenBrush("#26CBA6F7"),
    "Html" => FrozenBrush("#2689B4FA"),
    "Text" => FrozenBrush("#26A6E3A1"),
    "Image" => FrozenBrush("#26F9E2AF"),
    "File" => FrozenBrush("#26FAB387"),
    _ => FrozenBrush("#266C7086")
  };

  private static SolidColorBrush FrozenBrush(string hex)
  {
    var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex)!);
    brush.Freeze();
    return brush;
  }

  private static string Truncate(string text) =>
    text.Length > 120 ? text[..117] + "…" : text;
}
