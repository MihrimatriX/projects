using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranGoruntusu.Models;
using EkranGoruntusu.Services;
using Microsoft.Win32;
using NHotkey;
using NHotkey.Wpf;

namespace EkranGoruntusu.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly DatabaseService _db;

    [ObservableProperty] private ScreenshotItem? _selectedScreenshot;
    [ObservableProperty] private string _searchText = string.Empty;
    [ObservableProperty] private string _statusMessage = "0 kayıt · OCR hazır";
    [ObservableProperty] private bool _hasScreenshots;
    [ObservableProperty] private string _hotkeyDisplay = SettingsService.DisplayHotkey(SettingsService.DefaultHotkey);

    // Arama sonuç vermediğinde (geçmiş boş değilken) gösterilen boş durum.
    public bool IsSearchEmpty => HasScreenshots && FilteredScreenshots.IsEmpty;

    public ObservableCollection<ScreenshotItem> Screenshots { get; } = new();
    public ICollectionView FilteredScreenshots { get; }
    public SettingsService Settings { get; }

    public event Action? RequestStartCapture;
    public event Action? RequestShowMain;
    public event Action? RequestOpenSettings;
    /// <summary>Düzenleyici bu görüntüyle açılsın (görüntünün sahibi olay işleyicisidir).</summary>
    public event Action<System.Drawing.Bitmap>? RequestOpenEditor;

    private static Window? Owner => Application.Current?.MainWindow;

    // Onay kutuları ana pencereye bağlı açılır (uygulama ön planda değilken arkada kalmaz).
    private static MessageBoxResult Ask(string text, string caption, MessageBoxButton buttons, MessageBoxImage icon) =>
        Owner is { IsVisible: true } owner
            ? MessageBox.Show(owner, text, caption, buttons, icon)
            : MessageBox.Show(text, caption, buttons, icon);

    public MainViewModel()
    {
        var dataFolder = SettingsService.ResolveDataFolder();
        Settings = new SettingsService(dataFolder);
        string? startupWarning = null;
        try
        {
            _db = new DatabaseService(dataFolder, Settings.SaveFolder);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or NotSupportedException or ArgumentException)
        {
            // Ayarlardaki kayıt klasörü artık yok/erişilemez (ör. çıkarılmış sürücü): açılışta çökme yerine varsayılana dön.
            Settings.SaveFolder = Path.Combine(dataFolder, "screenshots");
            _db = new DatabaseService(dataFolder, Settings.SaveFolder);
            startupWarning = "Kayıt klasörüne erişilemedi; varsayılan klasöre dönüldü.";
        }

        FilteredScreenshots = CollectionViewSource.GetDefaultView(Screenshots);
        FilteredScreenshots.Filter = FilterScreenshot;

        var hotkeyWarning = ApplyHotkey(Settings.Hotkey); // klasör uyarısı olsa da kısayol kaydedilmeli
        startupWarning ??= hotkeyWarning;

        LoadScreenshots();
        // LoadScreenshots durum satırını yazar; uyarı onun üzerine gösterilir (önceden siliniyordu).
        if (startupWarning != null) StatusMessage = startupWarning;
    }

    public DatabaseService Database => _db;

    /// <summary>Global kısayolu kaydeder; başarısızsa kullanıcıya gösterilecek uyarıyı döndürür (eski kısayol bırakılır).</summary>
    public string? ApplyHotkey(string hotkey)
    {
        var display = SettingsService.DisplayHotkey(hotkey);
        if (!SettingsService.TryParseHotkey(hotkey, out var key, out var modifiers))
            return $"Geçersiz kısayol: {display}";
        try
        {
            HotkeyManager.Current.AddOrReplace("StartCapture", key, modifiers, OnGlobalHotkey);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Hotkey registration failed: {ex.Message}");
            return $"Kısayol ({display}) kaydedilemedi — başka bir uygulama kullanıyor olabilir; Ayarlar'dan başka bir kısayol seçin.";
        }
        HotkeyDisplay = display;
        if (Settings.Hotkey != hotkey) Settings.Hotkey = hotkey;
        return null;
    }

    private void OnGlobalHotkey(object? sender, HotkeyEventArgs e)
    {
        e.Handled = true;
        StartCapture();
    }

    [RelayCommand]
    public void LoadScreenshots()
    {
        Screenshots.Clear();
        foreach (var raw in _db.GetScreenshots())
        {
            Screenshots.Add(new ScreenshotItem(raw.Id, raw.ImagePath, raw.OcrText, raw.Timestamp));
        }

        FilteredScreenshots.Refresh();
        HasScreenshots = Screenshots.Count > 0;
        SelectedScreenshot = HasScreenshots ? Screenshots[0] : null;
        UpdateStatus();
        OnPropertyChanged(nameof(IsSearchEmpty));
    }

    partial void OnSearchTextChanged(string value)
    {
        FilteredScreenshots.Refresh();
        UpdateStatus();
        OnPropertyChanged(nameof(IsSearchEmpty));
    }

    [RelayCommand] private void ClearSearch() => SearchText = string.Empty;

    private void UpdateStatus()
    {
        var visible = 0;
        foreach (var _ in FilteredScreenshots) visible++;
        StatusMessage = $"{visible} kayıt · OCR hazır";
    }

    private bool FilterScreenshot(object obj)
    {
        if (obj is not ScreenshotItem item) return false;
        if (string.IsNullOrWhiteSpace(SearchText)) return true;
        var q = SearchText.Trim();
        return item.OcrText.Contains(q, StringComparison.OrdinalIgnoreCase) ||
               Path.GetFileName(item.ImagePath).Contains(q, StringComparison.OrdinalIgnoreCase);
    }

    [RelayCommand] public void StartCapture() => RequestStartCapture?.Invoke();
    [RelayCommand] public void OpenSettings() => RequestOpenSettings?.Invoke();

    // Var olan bir görseli düzenleyicide aç: işaretle, bulanıklaştır, OCR uygula, geçmişe kaydet.
    [RelayCommand]
    public void OpenImage()
    {
        var dialog = new OpenFileDialog
        {
            Title = "Düzenlenecek görseli seçin",
            Filter = "Görseller (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff|Tüm dosyalar (*.*)|*.*"
        };
        if (dialog.ShowDialog(Owner) == true) OpenInEditor(dialog.FileName);
    }

    [RelayCommand]
    public void EditScreenshot(ScreenshotItem? item)
    {
        if (item == null) return;
        if (!File.Exists(item.ImagePath))
        {
            StatusMessage = "Görsel dosyası bulunamadı (taşınmış ya da silinmiş olabilir).";
            return;
        }
        OpenInEditor(item.ImagePath);
    }

    private void OpenInEditor(string path)
    {
        System.Drawing.Bitmap bitmap;
        try { bitmap = ImageFile.Load(path); }
        catch (Exception ex) when (ex is IOException or ArgumentException or UnauthorizedAccessException or OutOfMemoryException)
        {
            StatusMessage = $"Görsel açılamadı: {Path.GetFileName(path)}";
            return;
        }
        RequestOpenEditor?.Invoke(bitmap);
    }

    [RelayCommand]
    public void DeleteScreenshot(ScreenshotItem? item)
    {
        if (item == null) return;
        // PNG dosyası da diskten silindiği için onay istenir.
        if (Ask($"\"{Path.GetFileName(item.ImagePath)}\" ve görsel dosyası silinsin mi?", "Kaydı sil",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            return;
        _db.DeleteScreenshot(item.Id, item.ImagePath);
        LoadScreenshots();
    }

    [RelayCommand]
    public void ShowInFolder(ScreenshotItem? item)
    {
        if (item == null) return;
        if (!File.Exists(item.ImagePath))
        {
            StatusMessage = "Görsel dosyası bulunamadı (taşınmış ya da silinmiş olabilir).";
            return;
        }
        System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{item.ImagePath}\"");
    }

    [RelayCommand]
    public void CopyImageToClipboard(ScreenshotItem? item)
    {
        if (item == null || !File.Exists(item.ImagePath)) return;
        try
        {
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(item.ImagePath);
            bitmap.EndInit();
            Clipboard.SetImage(bitmap);
            StatusMessage = "Görüntü panoya kopyalandı.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Kopyalama hatası: {ex.Message}";
        }
    }

    [RelayCommand]
    public void CopyTextToClipboard(ScreenshotItem? item)
    {
        if (item == null || !item.HasOcrText) return;
        try
        {
            Clipboard.SetText(item.OcrText);
            StatusMessage = "OCR metni panoya kopyalandı.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Kopyalama hatası: {ex.Message}";
        }
    }

    [RelayCommand]
    public void ClearHistory()
    {
        if (!HasScreenshots) return;
        if (Ask("Tüm geçmiş ve görsel dosyaları silinsin mi?", "Geçmişi temizle",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            return;

        _db.ClearHistory();
        LoadScreenshots();
    }

    public void SaveNewCapture(string path, string ocrText)
    {
        _db.SaveScreenshot(path, ocrText, Settings.HistoryLimit);
        LoadScreenshots();
        RequestShowMain?.Invoke();
    }

    public void ApplySaveFolder(string folder)
    {
        Directory.CreateDirectory(folder);
        Settings.SaveFolder = folder;
        _db.ScreenshotsFolder = folder;
    }
}
