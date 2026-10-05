using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranKaydi.Models;
using EkranKaydi.Services;
using EkranKaydi.Views;
using NHotkey;
using NHotkey.Wpf;

namespace EkranKaydi.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly DatabaseService _db = new();

    [ObservableProperty] private RecordingItem? _selectedRecording;
    [ObservableProperty] private string _statusMessage = "Hazır";
    [ObservableProperty] private int _recordingCount;
    [ObservableProperty] private string _ffmpegStatus = "";

    public ObservableCollection<RecordingItem> Recordings { get; } = [];

    public event Action? RequestStartRecording;
    public event Action? RequestShowMain;

    public MainViewModel()
    {
        try
        {
            HotkeyManager.Current.AddOrReplace("StartRecording", Key.R, ModifierKeys.Control | ModifierKeys.Alt, OnGlobalHotkey);
        }
        catch
        {
            StatusMessage = "Kısayol kaydedilemedi — uygulama içinden kayıt başlatabilirsiniz.";
        }

        Recordings.CollectionChanged += (_, _) => RecordingCount = Recordings.Count;
        LoadRecordings();
        if (!RefreshFfmpegStatus())
            StatusMessage = "ffmpeg bulunamadı — kayıt ve dışa aktarma için: winget install Gyan.FFmpeg";
    }

    public static readonly string[] VideoExtensions = [".mp4", ".mov", ".mkv", ".avi", ".webm", ".wmv"];

    public static bool IsSupportedVideo(string path) =>
        VideoExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);

    private bool RefreshFfmpegStatus()
    {
        var ok = FfmpegService.IsAvailable;
        FfmpegStatus = ok ? "ffmpeg hazır" : "ffmpeg yok";
        return ok;
    }

    /// <summary>ffmpeg yoksa kurulum talimatını gösterir ve false döner.</summary>
    public bool EnsureFfmpeg()
    {
        if (RefreshFfmpegStatus()) return true;
        MessageBox.Show(FfmpegService.MissingMessage, "ffmpeg gerekli", MessageBoxButton.OK, MessageBoxImage.Warning);
        StatusMessage = "ffmpeg bulunamadı — winget install Gyan.FFmpeg";
        return false;
    }

    private void OnGlobalHotkey(object? sender, HotkeyEventArgs e)
    {
        e.Handled = true;
        StartNewRecording();
    }

    [RelayCommand]
    public void LoadRecordings()
    {
        Recordings.Clear();
        foreach (var raw in _db.GetRecordings())
        {
            Recordings.Add(new RecordingItem(
                raw.Id, raw.FilePath, raw.Type, raw.DurationSeconds,
                raw.Width, raw.Height, raw.Timestamp));
        }

        SelectedRecording = Recordings.Count > 0 ? Recordings[0] : null;
        RecordingCount = Recordings.Count;
    }

    [RelayCommand]
    public void StartNewRecording()
    {
        if (EnsureFfmpeg()) RequestStartRecording?.Invoke();
    }

    /// <summary>Var olan bir videoyu kırpma editöründe açar (GIF/MP4'e dönüştürmek için).</summary>
    public void OpenVideoForConversion(string path)
    {
        if (!File.Exists(path) || !IsSupportedVideo(path))
        {
            StatusMessage = $"Desteklenmeyen dosya: {Path.GetFileName(path)}";
            return;
        }
        RefreshFfmpegStatus(); // yoksa önizleme yine açılır, dışa aktarmada talimat gösterilir
        new TrimWindow(path, "GIF", 15, this, isExistingRecording: true).Show();
        StatusMessage = $"Dönüştürülüyor: {Path.GetFileName(path)}";
    }

    [RelayCommand]
    public void ImportVideo()
    {
        var dlg = new Microsoft.Win32.OpenFileDialog
        {
            Title = "GIF'e dönüştürülecek videoyu seçin",
            Filter = "Video dosyaları|" + string.Join(";", VideoExtensions.Select(e => "*" + e)) + "|Tüm dosyalar|*.*"
        };
        if (dlg.ShowDialog() == true) OpenVideoForConversion(dlg.FileName);
    }

    [RelayCommand]
    public void CopyToClipboard(RecordingItem? item)
    {
        if (item == null || !File.Exists(item.FilePath))
        {
            StatusMessage = "Kopyalanacak kayıt dosyası bulunamadı.";
            return;
        }
        try
        {
            Clipboard.SetFileDropList([item.FilePath]);
            StatusMessage = $"Panoya kopyalandı: {Path.GetFileName(item.FilePath)} (sohbete/klasöre yapıştırabilirsiniz)";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Panoya kopyalanamadı: {ex.Message}";
        }
    }

    [RelayCommand]
    public void DeleteRecording(RecordingItem? item)
    {
        if (item == null) return;
        if (MessageBox.Show($"\"{Path.GetFileName(item.FilePath)}\" kaydı ve dosyası silinsin mi?", "Kaydı sil",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            return;

        // Önizleme MediaElement'i dosyayı kilitler; seçimi bırakınca kaynak boşaltılır, silme başarılı olur
        SelectedRecording = null;
        if (File.Exists(item.ThumbnailPath))
            try { File.Delete(item.ThumbnailPath); } catch { /* ponytail: best-effort thumb cleanup */ }

        _db.DeleteRecording(item.Id, item.FilePath);
        LoadRecordings();
        StatusMessage = "Kayıt silindi.";
    }

    [RelayCommand]
    public void RevealInExplorer(RecordingItem? item)
    {
        if (item == null || !File.Exists(item.FilePath)) return;
        try
        {
            Process.Start("explorer.exe", $"/select,\"{item.FilePath}\"");
            StatusMessage = "Klasör açıldı.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Klasör açılamadı: {ex.Message}";
        }
    }

    [RelayCommand]
    public void OpenExportFolder()
    {
        try
        {
            Process.Start("explorer.exe", _db.RecordingsFolder);
            StatusMessage = $"Klasör açıldı: {_db.RecordingsFolder}";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Klasör açılamadı: {ex.Message}";
        }
    }

    [RelayCommand]
    public void OpenTrimEditor(RecordingItem? item)
    {
        if (item == null || !File.Exists(item.FilePath))
        {
            StatusMessage = "Kayıt dosyası bulunamadı.";
            return;
        }

        if (!item.Type.Equals("MP4", StringComparison.OrdinalIgnoreCase))
        {
            MessageBox.Show("Trim editörü yalnızca MP4 kayıtları için kullanılabilir.", "Bilgi",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        new TrimWindow(item.FilePath, "MP4", 15, this, isExistingRecording: true).Show();
        StatusMessage = "Trim editörü açıldı.";
    }

    [RelayCommand]
    public void OpenRecording(RecordingItem? item)
    {
        if (item == null || !File.Exists(item.FilePath)) return;
        try
        {
            Process.Start(new ProcessStartInfo(item.FilePath) { UseShellExecute = true });
            StatusMessage = "Kayıt açıldı.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Dosya açılamadı: {ex.Message}";
        }
    }

    [RelayCommand]
    public void ClearHistory()
    {
        if (MessageBox.Show("Geçmişteki tüm kayıtlar ve dosyaları silinsin mi?\n(Listede görünmeyen eski dosyalar kayıt klasöründe kalır.)", "Geçmişi temizle",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            return;

        SelectedRecording = null; // önizleme dosya kilidini bırak
        var thumbFolder = AppPaths.ThumbnailsFolder;
        if (Directory.Exists(thumbFolder))
            try { Directory.Delete(thumbFolder, true); } catch { }

        _db.ClearHistory();
        LoadRecordings();
        StatusMessage = "Geçmiş temizlendi.";
    }

    public async Task SaveNewRecordingAsync(string tempMp4Path, string type, double duration, int w, int h, int fps)
    {
        if (!File.Exists(tempMp4Path))
            throw new FileNotFoundException("Kırpılmış kayıt dosyası bulunamadı.", tempMp4Path);

        var extension = type.ToLowerInvariant();
        var filename = $"recording_{DateTime.Now:yyyyMMdd_HHmmss}.{extension}";
        var finalPath = Path.Combine(_db.RecordingsFolder, filename);

        if (type.Equals("MP4", StringComparison.OrdinalIgnoreCase))
        {
            File.Move(tempMp4Path, finalPath, true);
            var newId = _db.SaveRecording(finalPath, type, duration, w, h);
            var item = new RecordingItem((int)newId, finalPath, type, duration, w, h, DateTime.Now);
            try { await FfmpegService.GenerateFirstFrameThumbnailAsync(finalPath, item.ThumbnailPath); }
            catch (Exception ex) { Debug.WriteLine($"Küçük resim üretilemedi: {ex.Message}"); } // kayıt zaten kaydedildi
        }
        else
        {
            var exportWidth = FfmpegService.NormalizeEvenWidth(w);
            await FfmpegService.ConvertMp4ToGifAsync(tempMp4Path, finalPath, fps, exportWidth);
            if (!File.Exists(finalPath) || new FileInfo(finalPath).Length < 100)
                throw new IOException("GIF oluşturulamadı — ffmpeg çıktı dosyası boş veya yok.");

            if (File.Exists(tempMp4Path))
                try { File.Delete(tempMp4Path); } catch { }

            _db.SaveRecording(finalPath, type, duration, exportWidth, h);
        }

        LoadRecordings();
        SelectedRecording = Recordings.FirstOrDefault(r => r.FilePath == finalPath) ?? Recordings.FirstOrDefault();
        StatusMessage = $"Kayıt kaydedildi: {Path.GetFileName(finalPath)}";
        RequestShowMain?.Invoke();
    }
}
