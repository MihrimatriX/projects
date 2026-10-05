using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Data;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DosyaSifreleme.Models;
using DosyaSifreleme.Services;
using Microsoft.Win32;

namespace DosyaSifreleme.ViewModels;

public partial class DashboardViewModel : ObservableObject
{
    private readonly MainViewModel _main;
    private readonly VaultService _vault;

    [ObservableProperty] private string _vaultPath = string.Empty;
    // Açıksa eklenen dosyanın şifreli kopyası doğrulandıktan sonra orijinali silinir (kasaya taşı).
    [ObservableProperty] private bool _deleteOriginalAfterAdd;
    [ObservableProperty] private string _searchText = string.Empty;
    [ObservableProperty] private VaultFileItem? _selectedFile;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private string _autoLockText = string.Empty;
    [ObservableProperty] private bool _isAutoLockWarning;
    [ObservableProperty] private bool _isExportDialogOpen;
    [ObservableProperty] private bool _isExporting;
    [ObservableProperty] private string _exportError = string.Empty;
    [ObservableProperty] private VaultFileItem? _exportTarget;
    [ObservableProperty] private int _autoLockMinutes;
    [ObservableProperty] private bool _isBusy;

    public int[] AutoLockChoices => AppSettings.AutoLockChoices;

    /// <summary>Otomatik kilit süresi değişti (MainWindow sayacı yeniden başlatır).</summary>
    public event Action? AutoLockChanged;

    private static readonly CompareInfo TrCompare = CultureInfo.GetCultureInfo("tr-TR").CompareInfo;

    public ObservableCollection<VaultFileItem> Files { get; } = new();
    public ICollectionView FilteredFiles { get; }

    public string VaultDisplayName => string.IsNullOrWhiteSpace(VaultPath)
        ? "Kişisel Kasa"
        : Path.GetFileName(VaultPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));

    public string FileCountText => $"{Files.Count} dosya · AES-256-GCM";

    public string TotalSizeText => new VaultFileItem { SizeBytes = Files.Sum(f => f.SizeBytes) }.DisplaySize;

    // Arama sonuç vermediğinde (kasa boş değilken) gösterilen boş durum.
    public bool IsSearchEmpty => Files.Count > 0 && FilteredFiles.IsEmpty;

    public DashboardViewModel(MainViewModel main, VaultService vault)
    {
        _main = main;
        _vault = vault;
        VaultPath = vault.ActiveVaultPath ?? string.Empty;
        _autoLockMinutes = main.Settings.AutoLockMinutes;

        FilteredFiles = CollectionViewSource.GetDefaultView(Files);
        FilteredFiles.Filter = obj => obj is VaultFileItem item &&
            (string.IsNullOrWhiteSpace(SearchText) ||
             TrCompare.IndexOf(item.FileName, SearchText.Trim(), CompareOptions.IgnoreCase) >= 0);

        RefreshFileList();
    }

    public void UpdateAutoLock(int secondsRemaining)
    {
        if (secondsRemaining <= 0)
        {
            AutoLockText = "Kilitleniyor…";
            IsAutoLockWarning = true;
            return;
        }

        var m = secondsRemaining / 60;
        var s = secondsRemaining % 60;
        AutoLockText = $"{m}:{s:D2} sonra kilitlenir";
        IsAutoLockWarning = secondsRemaining <= 60;
    }

    [RelayCommand]
    private async Task AddFileAsync()
    {
        var dialog = new OpenFileDialog { Title = "Kasaya Eklenecek Dosyayı Seçin", Multiselect = true };
        if (dialog.ShowDialog(App.Owner) != true) return;

        await EncryptAndAddAsync(dialog.FileNames);
    }

    [RelayCommand]
    private async Task DragDropAddAsync(string[]? filePaths)
    {
        if (filePaths == null) return;
        var files = filePaths.Where(File.Exists).ToArray();
        if (files.Length < filePaths.Length)
            StatusMessage = "Klasörler eklenmez; yalnızca dosyalar kasaya alınır.";
        await EncryptAndAddAsync(files);
    }

    [RelayCommand]
    private void RequestExport(VaultFileItem? file)
    {
        var target = file ?? SelectedFile;
        if (target == null) return;

        ExportTarget = target;
        ExportError = string.Empty;
        IsExporting = false;
        IsExportDialogOpen = true;
    }

    [RelayCommand]
    private void CancelExport()
    {
        IsExportDialogOpen = false;
        ExportTarget = null;
        ExportError = string.Empty;
        IsExporting = false;
    }

    [RelayCommand]
    private async Task ConfirmExportAsync()
    {
        if (ExportTarget == null) return;

        var dialog = new SaveFileDialog
        {
            Title = "Dosyayı Kasadan Çıkar (Deşifre Et)",
            FileName = ExportTarget.FileName,
            DefaultExt = ExportTarget.Extension,
            Filter = $"Orijinal (*{ExportTarget.Extension})|*{ExportTarget.Extension}|Tüm Dosyalar (*.*)|*.*",
            InitialDirectory = LastExportFolder
        };

        if (dialog.ShowDialog(App.Owner) != true)
        {
            CancelExport();
            return;
        }

        IsExporting = true;
        ExportError = string.Empty;

        RememberExportFolder(Path.GetDirectoryName(dialog.FileName));
        var target = ExportTarget;
        try
        {
            await Task.Run(() => _vault.ExportFile(target, dialog.FileName));
            StatusMessage = $"Çıkarıldı: {target.FileName}";
            IsExportDialogOpen = false;
            ExportTarget = null;
        }
        catch (Exception ex)
        {
            ExportError = $"Çıkarma başarısız: {ex.Message}";
        }
        finally
        {
            IsExporting = false;
        }
    }

    // Çıkarma diyalogları son kullanılan klasörde açılır (yoksa Windows varsayılanı).
    private string LastExportFolder =>
        Directory.Exists(_main.Settings.LastExportFolder) ? _main.Settings.LastExportFolder : string.Empty;

    private void RememberExportFolder(string? folder)
    {
        if (string.IsNullOrEmpty(folder) || folder == _main.Settings.LastExportFolder) return;
        _main.Settings.LastExportFolder = folder;
        _main.Settings.Save();
    }

    [RelayCommand]
    private void ShowFileInfo(VaultFileItem? file)
    {
        var target = file ?? SelectedFile;
        if (target == null) return;

        MessageBox.Show(App.Owner,
            $"Dosya: {target.FileName}\nBoyut: {target.DisplaySize}\nUzantı: {target.Extension}\nEklenme: {target.DateAdded:g}",
            "Dosya Bilgisi",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    [RelayCommand]
    private void DeleteFile()
    {
        var target = SelectedFile;
        if (target == null) return;

        var result = MessageBox.Show(App.Owner,
            $"\"{target.FileName}\" kasadan kalıcı olarak silinsin mi?",
            "Dosyayı Sil",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result != MessageBoxResult.Yes) return;

        try
        {
            var name = target.FileName;
            _vault.DeleteFile(target);
            Files.Remove(target);
            SelectedFile = null;
            OnFilesChanged();
            StatusMessage = $"Silindi: {name}";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Silme hatası: {ex.Message}";
        }
    }

    [RelayCommand]
    private async Task ExportAllAsync()
    {
        if (Files.Count == 0) return;
        var dialog = new OpenFolderDialog { Title = "Tüm dosyaların çıkarılacağı klasörü seçin", InitialDirectory = LastExportFolder };
        if (dialog.ShowDialog(App.Owner) != true) return;
        RememberExportFolder(dialog.FolderName);

        IsBusy = true;
        StatusMessage = "Tüm dosyalar çıkarılıyor…";
        try
        {
            var n = await Task.Run(() => _vault.ExportAll(dialog.FolderName));
            StatusMessage = $"{n} dosya çıkarıldı: {Path.GetFileName(dialog.FolderName.TrimEnd(Path.DirectorySeparatorChar))}";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Çıkarma hatası: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void ClearSearch() => SearchText = string.Empty;

    [RelayCommand]
    private void LockVault()
    {
        _main.NavigateToLogin();
        _main.LoginVM.InfoMessage = "Kasa kilitlendi.";
    }

    partial void OnSearchTextChanged(string value)
    {
        FilteredFiles.Refresh();
        OnPropertyChanged(nameof(IsSearchEmpty));
    }

    partial void OnAutoLockMinutesChanged(int value)
    {
        _main.Settings.AutoLockMinutes = value;
        _main.Settings.Save();
        AutoLockChanged?.Invoke();
    }

    private void OnFilesChanged()
    {
        FilteredFiles.Refresh();
        OnPropertyChanged(nameof(FileCountText));
        OnPropertyChanged(nameof(TotalSizeText));
        OnPropertyChanged(nameof(IsSearchEmpty));
    }

    // Şifreleme arka planda: büyük dosyalarda pencere donmaz.
    private async Task EncryptAndAddAsync(IReadOnlyList<string> filePaths)
    {
        if (filePaths.Count == 0) return;
        var move = DeleteOriginalAfterAdd;
        IsBusy = true;
        try
        {
            foreach (var filePath in filePaths)
            {
                var name = Path.GetFileName(filePath);
                StatusMessage = $"Şifreleniyor: {name}…";
                try
                {
                    await Task.Run(() =>
                    {
                        if (move) _vault.MoveFileIntoVault(filePath);
                        else _vault.AddFile(filePath);
                    });
                    StatusMessage = move ? $"Taşındı (orijinal silindi): {name}" : $"Eklendi: {name}";
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Ekleme hatası: {ex.Message}";
                }
            }
        }
        finally
        {
            IsBusy = false;
        }
        if (_vault.IsOpen) RefreshFileList();
    }

    private void RefreshFileList()
    {
        try
        {
            Files.Clear();
            foreach (var item in _vault.GetFiles())
                Files.Add(item);
            OnFilesChanged();
        }
        catch (Exception ex)
        {
            StatusMessage = $"Liste yüklenemedi: {ex.Message}";
        }
    }
}
