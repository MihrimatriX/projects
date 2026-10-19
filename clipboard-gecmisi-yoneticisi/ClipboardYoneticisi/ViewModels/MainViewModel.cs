using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using ClipboardYoneticisi.Helpers;
using ClipboardYoneticisi.Models;
using ClipboardYoneticisi.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NHotkey.Wpf;

namespace ClipboardYoneticisi.ViewModels
{
    public partial class MainViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;
        private readonly ClipboardMonitorService _monitorService;
        private readonly StackPasteService _stackService;
        private readonly ExportImportService _exportImportService;
        private readonly EncryptionService _encryption;

        [ObservableProperty]
        private string _searchText = string.Empty;

        [ObservableProperty]
        private ClipboardItem? _selectedItem;

        [ObservableProperty]
        private string _selectedFilter = "All";

        [ObservableProperty]
        private bool _isLocked;

        [ObservableProperty]
        private int _stackCount;

        [ObservableProperty]
        private string _hotkeyWarningText = string.Empty;

        private List<ClipboardItem> _selectedItems = [];

        [ObservableProperty]
        private int _selectedItemsCount;

        [ObservableProperty]
        private bool _hasMultiSelection;

        [ObservableProperty]
        private bool _isEncryptionEnabled;

        [ObservableProperty]
        private bool _hasPinnedItems;

        [ObservableProperty]
        private string _emptyStateText = "Henüz kopyalanan öğe yok";

        /// <summary>Alt bilgi satırındaki kısa durum mesajı (ör. "2 öğe silindi · Ctrl+Z geri al").</summary>
        [ObservableProperty]
        private string _statusText = string.Empty;

        // Son silinen öğeler (Ctrl+Z ile geri alınır). Görsel dosyaları bir sonraki silmeye/çıkışa kadar tutulur.
        private List<ClipboardItem> _undoItems = [];

        public ObservableCollection<FilterOption> FilterOptions { get; } = new()
        {
            new FilterOption("All", "Tümü"),
            new FilterOption("Text", "Metin"),
            new FilterOption("Image", "Görsel"),
            new FilterOption("Code", "Kod"),
            new FilterOption("Url", "URL")
        };

        public event Action? RequestShow;
        public event Action? RequestHide;
        public event Action? RequestExit;
        public event Action? RequestSettings;
        public event Action? RequestUnlock;
        public event Action? RequestAbout;
        public event Action? RequestHelp;
        public event Action? RequestWelcome;
        public event Func<Task<string?>>? RequestExportFile;
        public event Func<Task<string?>>? RequestImportFile;
        public event Action<string, string>? RequestTrayNotification;
        public event Action<UpdateInfo>? RequestShowUpdate;
        public event Action? RequestCopyFlash;
        public event Action<IReadOnlyCollection<int>>? RequestReselect;

        public Func<bool>? IsWindowVisibleCheck { get; set; }

        public ObservableCollection<ClipboardItem> History { get; } = new();

        public MainViewModel()
        {
            _dbService = new DatabaseService();
            _monitorService = new ClipboardMonitorService(_dbService);
            _stackService = new StackPasteService();
            _exportImportService = new ExportImportService(_dbService);
            _encryption = EncryptionService.Instance;

            _monitorService.ClipboardChanged += MonitorService_ClipboardChanged;
            _stackService.StackChanged += () => StackCount = _stackService.Count;

            ApplyStartupSetting();
            RegisterHotkeys();
            UpdateLockState();

            _dbService.PurgeOlderThan(SettingsService.Instance.Settings.AutoDeleteDays);

            if (_encryption.IsEnabled && !_encryption.IsUnlocked)
                RequestUnlock?.Invoke();
            else
            {
                LoadHistory();
                if (!SettingsService.Instance.Settings.FirstRunCompleted)
                    RequestWelcome?.Invoke();
            }

            _ = RunStartupUpdateCheckAsync();
        }

        private async Task RunStartupUpdateCheckAsync()
        {
            await Task.Delay(TimeSpan.FromSeconds(3));
            await CheckForUpdatesInternalAsync(force: false);
        }

        public ClipboardMonitorService MonitorService => _monitorService;

        private static void ApplyStartupSetting()
        {
            var settings = SettingsService.Instance.Settings;
            if (StartupService.IsEnabled() != settings.StartWithWindows)
                StartupService.SetEnabled(settings.StartWithWindows);
        }

        public void RegisterHotkeys()
        {
            var settings = SettingsService.Instance.Settings;
            HotkeyWarningText = string.Empty;

            try
            {
                HotkeyManager.Current.Remove("ShowClipboard");
                HotkeyManager.Current.Remove("StackPaste");

                var showOk = false;
                var stackOk = false;

                if (HotkeyParser.TryParse(settings.ShowHotkey, out var showKey, out var showMods))
                {
                    HotkeyManager.Current.AddOrReplace("ShowClipboard", showKey, showMods, OnGlobalHotkey);
                    showOk = true;
                }

                if (HotkeyParser.TryParse(settings.StackHotkey, out var stackKey, out var stackMods))
                {
                    HotkeyManager.Current.AddOrReplace("StackPaste", stackKey, stackMods, OnStackPasteHotkey);
                    stackOk = true;
                }

                if (!showOk || !stackOk)
                {
                    HotkeyWarningText = "⚠ Kısayol kaydı başarısız — ayarlardan kontrol edin";
                    LogService.Warning("Hotkey registration incomplete.");
                }
            }
            catch (Exception ex)
            {
                HotkeyWarningText = "⚠ Kısayol başka uygulama tarafından kullanılıyor olabilir";
                LogService.Warning($"Failed to register hotkey: {ex.Message}");
            }
        }

        private void MonitorService_ClipboardChanged(object? sender, EventArgs e)
        {
            App.Current.Dispatcher.Invoke(() =>
            {
                LoadHistory();
                NotifyCaptureIfNeeded();
            });
        }

        private void NotifyCaptureIfNeeded()
        {
            var settings = SettingsService.Instance.Settings;
            if (!settings.EnableTrayNotifications || !settings.NotifyOnCapture)
                return;

            if (IsWindowVisibleCheck?.Invoke() == true)
                return;

            if (History.Count == 0)
                return;

            RequestTrayNotification?.Invoke("Yeni pano kaydı", History[0].PreviewText);
        }

        private void NotifyStackPaste(int remaining)
        {
            var settings = SettingsService.Instance.Settings;
            if (!settings.EnableTrayNotifications || !settings.NotifyOnStackPaste)
                return;

            var msg = remaining > 0
                ? $"Stack'te {remaining} öğe kaldı"
                : "Stack boş";
            RequestTrayNotification?.Invoke("Stack yapıştır", msg);
        }

        public void SetSelectedItems(IReadOnlyList<ClipboardItem> items)
        {
            _selectedItems = items.ToList();
            SelectedItemsCount = _selectedItems.Count;
            HasMultiSelection = SelectedItemsCount > 1;
            // SelectedItem iki yonlu bagli: secim icindeki bir ogeyi degistirmek ListBox'a geri yazilip
            // coklu secimi tek ogeye indiriyordu. Yalnizca secim disinda kaldiysa guncelle.
            if (SelectedItem == null || !_selectedItems.Contains(SelectedItem))
                SelectedItem = _selectedItems.FirstOrDefault();
        }

        private void OnGlobalHotkey(object? sender, NHotkey.HotkeyEventArgs e)
        {
            e.Handled = true;
            if (_encryption.IsEnabled && !_encryption.IsUnlocked)
            {
                RequestUnlock?.Invoke();
                return;
            }
            RequestShow?.Invoke();
        }

        private void OnStackPasteHotkey(object? sender, NHotkey.HotkeyEventArgs e)
        {
            e.Handled = true;
            PasteNextFromStack();
        }

        public void UpdateLockState()
        {
            IsLocked = _encryption.IsEnabled && !_encryption.IsUnlocked;
            IsEncryptionEnabled = _encryption.IsEnabled;
        }

        public void OnSettingsSaved(bool encryptionChanged)
        {
            if (encryptionChanged)
            {
                if (!_encryption.IsEnabled)
                {
                    _dbService.ReencryptAll(false);
                    _encryption.DisableEncryption();
                }
                else
                {
                    _dbService.ReencryptAll(true);
                }
            }

            ApplyStartupSetting();
            RegisterHotkeys();
            _dbService.PurgeOlderThan(SettingsService.Instance.Settings.AutoDeleteDays);
            UpdateLockState();

            if (_encryption.IsEnabled && !_encryption.IsUnlocked)
                RequestUnlock?.Invoke();
            else
                LoadHistory();
        }

        [RelayCommand]
        public void PromptUnlock() => RequestUnlock?.Invoke();

        partial void OnSearchTextChanged(string value) => LoadHistory();

        partial void OnSelectedFilterChanged(string value) => LoadHistory();

        [RelayCommand]
        public void SelectFilter(string filterKey) => SelectedFilter = filterKey;

        [RelayCommand]
        public void LoadHistory()
        {
            if (IsLocked)
            {
                History.Clear();
                return;
            }

            var rawItems = _dbService.GetItems(string.IsNullOrWhiteSpace(SearchText) ? null : SearchText);
            // Liste yeniden kurulurken secim kayboluyordu (Enter/Ctrl+P sonrasi klavye akisi kopuyordu): koru.
            var keepId = SelectedItem?.Id;
            var keepIds = _selectedItems.Count > 1 ? _selectedItems.Select(i => i.Id).ToList() : null;
            History.Clear();

            foreach (var raw in rawItems)
            {
                var item = new ClipboardItem(
                    raw.Id,
                    raw.Type,
                    raw.Content,
                    raw.Timestamp,
                    raw.IsPinned,
                    raw.OcrText
                );

                if (!MatchesFilter(item))
                    continue;

                History.Add(item);
            }

            if (keepId != null)
                SelectedItem = History.FirstOrDefault(i => i.Id == keepId);
            // Arka planda yeni kopya yakalaninca coklu secim kayboluyordu: gorunume geri sectir.
            if (keepIds != null)
                RequestReselect?.Invoke(keepIds);

            HasPinnedItems = History.Any(i => i.IsPinned);
            EmptyStateText = !string.IsNullOrWhiteSpace(SearchText) || SelectedFilter != "All"
                ? "Eşleşme bulunamadı"
                : "Henüz kopyalanan öğe yok";
        }

        private bool MatchesFilter(ClipboardItem item)
        {
            if (SelectedFilter == "All")
                return item.FilterKey != "Other";

            return item.FilterKey == SelectedFilter;
        }

        [RelayCommand]
        public void CopyItem(ClipboardItem? item) => CopyItemWithTransform(item, TransformType.None);

        public void CopyItemWithTransform(ClipboardItem? item, TransformType transform)
        {
            if (item == null || IsLocked)
                return;

            _monitorService.CopyToClipboard(item.Type, item.Content, transform);
            _dbService.SaveItem(item.Type, item.Content, item.OcrText);
            LoadHistory();
            RequestCopyFlash?.Invoke();

            if (SettingsService.Instance.Settings.AutoPasteAfterSelect)
            {
                Task.Run(() => PasteSimulator.SimulatePaste());
                RequestHide?.Invoke();
            }
        }

        [RelayCommand]
        public void CopyOcrText(ClipboardItem? item)
        {
            if (item == null || !item.HasOcrText || IsLocked)
                return;

            _monitorService.CopyToClipboard("Text", item.OcrText!, TransformType.None);
            RequestHide?.Invoke();

            if (SettingsService.Instance.Settings.AutoPasteAfterSelect)
                Task.Run(() => PasteSimulator.SimulatePaste());
        }

        [RelayCommand]
        public void DeleteItem(ClipboardItem? item)
        {
            if (item == null || IsLocked)
                return;

            var index = History.IndexOf(item);
            _dbService.DeleteItem(item.Id, item.Type, item.Content, deleteImageFile: false);
            RememberForUndo([item]);
            LoadHistory();
            // Silinen yerine ayni siradaki oge secilsin (art arda Delete ile temizleme).
            if (index >= 0 && History.Count > 0)
                SelectedItem = History[Math.Min(index, History.Count - 1)];
        }

        private void RememberForUndo(List<ClipboardItem> items)
        {
            FlushUndo();
            _undoItems = items;
            StatusText = $"{items.Count} öğe silindi · Ctrl+Z geri al";
        }

        /// <summary>Geri alınamayacak hale gelen silinmiş görsellerin dosyalarını siler.</summary>
        public void FlushUndo()
        {
            // Gorsel dosya adlari icerige gore: ayni gorsel tekrar kopyalandiysa dosya yeni kayda aittir, silme.
            var images = _undoItems.Where(i => i.Type == "Image").ToList();
            if (images.Count > 0 && !IsLocked)
            {
                var live = _dbService.GetItems().Where(i => i.Type == "Image").Select(i => i.Content).ToHashSet();
                foreach (var item in images.Where(i => !live.Contains(i.Content)))
                    DatabaseService.TryDeleteImageFile(item.Content);
            }
            _undoItems = [];
        }

        [RelayCommand]
        public void UndoDelete()
        {
            if (IsLocked || _undoItems.Count == 0)
                return;

            foreach (var item in _undoItems)
                _dbService.SaveItem(item.Type, item.Content, item.OcrText, item.Timestamp, item.IsPinned);

            StatusText = $"{_undoItems.Count} öğe geri alındı";
            _undoItems = [];
            LoadHistory();
        }

        [RelayCommand]
        public void TogglePin(ClipboardItem? item)
        {
            if (item == null || IsLocked)
                return;

            _dbService.TogglePin(item.Id, !item.IsPinned);
            LoadHistory();
        }

        [RelayCommand]
        public void AddSelectedToStack()
        {
            if (IsLocked || _selectedItems.Count == 0)
                return;

            _stackService.EnqueueMany(_selectedItems);
            RequestTrayNotification?.Invoke("Stack", $"{_selectedItems.Count} öğe eklendi");
        }

        [RelayCommand]
        public void DeleteSelectedItems()
        {
            if (IsLocked || _selectedItems.Count == 0)
                return;

            var result = MessageBox.Show(
                $"{_selectedItems.Count} öğe silinsin mi?",
                "Toplu silme",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (result != MessageBoxResult.Yes)
                return;

            _dbService.DeleteItems(_selectedItems.Select(i => (i.Id, i.Type, i.Content)), deleteImageFiles: false);
            RememberForUndo(_selectedItems.ToList());
            LoadHistory();
        }

        [RelayCommand]
        public void AddToStack(ClipboardItem? item)
        {
            if (item == null || IsLocked)
                return;

            _stackService.Enqueue(item);
            StatusText = $"Stack'e eklendi ({_stackService.Count})";
        }

        [RelayCommand]
        public void PasteNextFromStack()
        {
            if (IsLocked || !_stackService.TryDequeue(out var type, out var content))
                return;

            _monitorService.CopyToClipboard(type, content);
            RequestHide?.Invoke();

            if (SettingsService.Instance.Settings.AutoPasteAfterSelect)
                Task.Run(() => PasteSimulator.SimulatePaste());

            NotifyStackPaste(_stackService.Count);
        }

        [RelayCommand]
        public void ClearStack()
        {
            _stackService.Clear();
            StatusText = "Stack temizlendi";
        }

        [RelayCommand]
        public async Task ExportHistoryAsync()
        {
            if (IsLocked || RequestExportFile == null)
                return;

            var path = await RequestExportFile.Invoke();
            if (string.IsNullOrWhiteSpace(path))
                return;

            try
            {
                var count = await _exportImportService.ExportToFileAsync(path);
                MessageBox.Show($"{count} öğe dışa aktarıldı.", "Yedekleme", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                LogService.Error("Export failed", ex);
                MessageBox.Show($"Dışa aktarma başarısız: {ex.Message}", "Yedekleme", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        [RelayCommand]
        public async Task ImportHistoryAsync()
        {
            if (IsLocked || RequestImportFile == null)
                return;

            var path = await RequestImportFile.Invoke();
            if (string.IsNullOrWhiteSpace(path))
                return;

            var merge = MessageBox.Show(
                "Mevcut geçmişle birleştirilsin mi?\n\nHayır = önce temizle, sonra içe aktar",
                "İçe Aktarma",
                MessageBoxButton.YesNoCancel,
                MessageBoxImage.Question);

            if (merge == MessageBoxResult.Cancel)
                return;

            try
            {
                var count = await _exportImportService.ImportFromFileAsync(path, merge == MessageBoxResult.Yes);
                LoadHistory();
                MessageBox.Show($"{count} öğe içe aktarıldı.", "İçe Aktarma", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                LogService.Error("Import failed", ex);
                MessageBox.Show($"İçe aktarma başarısız: {ex.Message}", "İçe Aktarma", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        [RelayCommand]
        public void ClearAll()
        {
            if (IsLocked)
                return;

            // Tepsi menüsünden tek tıkla tüm geçmiş gidiyordu: onay iste.
            var answer = MessageBox.Show(
                "Sabitlenmemiş tüm öğeler silinsin mi?\n\nSabitlenmiş öğeler korunur. Bu işlem geri alınamaz.",
                "Geçmişi temizle",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);
            if (answer != MessageBoxResult.Yes)
                return;

            FlushUndo();
            _dbService.ClearHistory();
            StatusText = "Geçmiş temizlendi";
            LoadHistory();
        }

        [RelayCommand]
        public void ShowMainWindow()
        {
            if (_encryption.IsEnabled && !_encryption.IsUnlocked)
            {
                RequestUnlock?.Invoke();
                return;
            }
            RequestShow?.Invoke();
        }

        [RelayCommand]
        public void OpenSettings()
        {
            // Kilitliyken sifreleme kapatilirsa anahtar olmadan kayitlar cozulemez ve kaybolur
            if (IsLocked)
            {
                RequestUnlock?.Invoke();
                return;
            }
            RequestSettings?.Invoke();
        }

        [RelayCommand]
        public void OpenAbout() => RequestAbout?.Invoke();

        [RelayCommand]
        public async Task CheckForUpdatesAsync() => await CheckForUpdatesInternalAsync(force: true);

        private async Task CheckForUpdatesInternalAsync(bool force)
        {
            try
            {
                var info = await new UpdateCheckService().CheckForUpdatesAsync(force);
                if (info != null)
                {
                    App.Current.Dispatcher.Invoke(() => RequestShowUpdate?.Invoke(info));
                    return;
                }

                if (force)
                {
                    MessageBox.Show(
                        "Güncel sürümü kullanıyorsunuz.",
                        "Güncelleme",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                LogService.Warning($"Update check failed: {ex.Message}");
                if (force)
                {
                    MessageBox.Show(
                        "Güncelleme kontrol edilemedi. İnternet bağlantınızı veya güncelleme adresini kontrol edin.",
                        "Güncelleme",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);
                }
            }
        }

        [RelayCommand]
        public void OpenHelp() => RequestHelp?.Invoke();

        [RelayCommand]
        public void LockSession()
        {
            if (!_encryption.IsEnabled)
                return;

            _encryption.Lock();
            UpdateLockState();
            LoadHistory();
        }

        [RelayCommand]
        public void ExitApplication()
        {
            FlushUndo();
            _monitorService.RemoveHook();
            RequestExit?.Invoke();
        }

        public bool TryUnlock(string password)
        {
            if (!_encryption.HasPassword)
            {
                if (string.IsNullOrWhiteSpace(password))
                    return false;
                _encryption.SetupPassword(password);
            }
            else if (!_encryption.Unlock(password))
            {
                return false;
            }

            UpdateLockState();
            LoadHistory();
            return true;
        }
    }

    public class FilterOption(string key, string label)
    {
        public string Key { get; } = key;
        public string Label { get; } = label;
    }
}
