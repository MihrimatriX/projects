using CanliDuvarKagidi.Core.Models;
using CanliDuvarKagidi.Core.Services;
using CanliDuvarKagidi_Shell.Models;
using CanliDuvarKagidi_Shell.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.System;

namespace CanliDuvarKagidi_Shell;

public sealed partial class MainPage : Page
{
    private readonly List<WallpaperManifest> _installedItems = [];
    private readonly List<CatalogEntry> _catalogItems = [];
    private readonly List<MonitorInfo> _monitors = [];
    private string _currentTag = "installed";
    private bool _catalogLoadedOnce;
    private bool _busy;

    public MainPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        AppServices.Engine.SessionsChanged += (_, _) => DispatcherQueue.TryEnqueue(RefreshMonitors);
        AppServices.StartupCompleted += () => DispatcherQueue.TryEnqueue(RefreshAll);
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        LoadSettingsUi();
        RefreshAll();
        UpdatePageHeader("installed");
        NavView.SelectedItem = NavView.MenuItems[0];
    }

    private void RefreshAll()
    {
        RefreshInstalled();
        RefreshMonitors();
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item || item.Tag is not string tag)
            return;

        _currentTag = tag;
        InstalledPanel.Visibility = tag == "installed" ? Visibility.Visible : Visibility.Collapsed;
        CatalogPanel.Visibility = tag == "catalog" ? Visibility.Visible : Visibility.Collapsed;
        MonitorsPanel.Visibility = tag == "monitors" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPanel.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;
        UpdatePageHeader(tag);

        // Magaza ilk acildiginda bos durum yerine katalog dogrudan gelsin
        if (tag == "catalog" && !_catalogLoadedOnce)
            LoadCatalog_Click(this, new RoutedEventArgs());
    }

    private void Navigate(int index) => NavView.SelectedItem = NavView.MenuItems[index];

    private void UpdatePageHeader(string tag)
    {
        switch (tag)
        {
            case "catalog":
                PageTitle.Text = "Mağaza";
                PageSubtitle.Text = "Self-host katalogdan duvar kağıdı keşfedin, indirin ve kurun.";
                break;
            case "monitors":
                PageTitle.Text = "Monitörler";
                PageSubtitle.Text = "Her monitöre farklı duvar kağıdı atayın ve aktif oturumları görüntüleyin.";
                break;
            case "settings":
                PageTitle.Text = "Ayarlar";
                PageSubtitle.Text = "Katalog adresi, başlangıç davranışı ve depolama tercihlerinizi yönetin.";
                break;
            default:
                PageTitle.Text = "Kütüphanem";
                PageSubtitle.Text = "Kurulu duvar kağıtlarını yönetin ve monitöre uygulayın.";
                break;
        }
    }

    private void LoadSettingsUi()
    {
        var settings = AppServices.Settings.Load();
        CatalogUrlBox.Text = settings.CatalogUrl;
        RunAtStartupSwitch.IsOn = settings.RunAtStartup;
        PauseFullscreenSwitch.IsOn = settings.PauseOnFullscreen;
    }

    private void RefreshInstalled()
    {
        // Secimi koru: yeniden doldurma ComboBox secimini sifirlar (ogeler _installedItems ile birebir)
        var picked = WallpaperPicker.SelectedIndex;
        var selectedId = picked >= 0 && picked < _installedItems.Count ? _installedItems[picked].Id : null;

        _installedItems.Clear();
        _installedItems.AddRange(AppServices.Installed.ListInstalled());
        InstalledCountBadge.Text = _installedItems.Count.ToString();
        ApplyLibraryFilter();

        WallpaperPicker.Items.Clear();
        foreach (var item in _installedItems)
            WallpaperPicker.Items.Add(item.Title);
        var keep = _installedItems.FindIndex(w => w.Id == selectedId);
        WallpaperPicker.SelectedIndex = keep >= 0 ? keep : (_installedItems.Count > 0 ? 0 : -1);
    }

    private void ApplyLibraryFilter()
    {
        var query = SearchBox.Text;
        var selectedId = (InstalledGrid.SelectedItem as WallpaperListItem)?.Id;
        var items = _installedItems.Where(w => w.Matches(query)).Select(ToWallpaperListItem).ToList();
        InstalledGrid.ItemsSource = items;
        InstalledGrid.SelectedItem = items.FirstOrDefault(i => i.Id == selectedId);

        var empty = items.Count == 0;
        InstalledEmpty.Visibility = empty ? Visibility.Visible : Visibility.Collapsed;
        InstalledGrid.Visibility = empty ? Visibility.Collapsed : Visibility.Visible;
        var filtered = _installedItems.Count > 0;
        InstalledEmptyTitle.Text = filtered ? "Eşleşen duvar kağıdı yok" : "Henüz duvar kağıdı yok";
        InstalledEmptyBody.Text = filtered
            ? $"\"{query.Trim()}\" için sonuç bulunamadı. Aramayı temizleyin ya da farklı bir kelime deneyin."
            : "Mağaza sekmesinden duvar kağıdı indirin ya da kendi görsel/videonuzu buraya sürükleyin.";
        GoToCatalogButton.Visibility = filtered ? Visibility.Collapsed : Visibility.Visible;
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e) => ApplyLibraryFilter();

    private void RefreshMonitors()
    {
        var selectedMonitorId = MonitorPicker.SelectedIndex >= 0 && MonitorPicker.SelectedIndex < _monitors.Count
            ? _monitors[MonitorPicker.SelectedIndex].Id
            : null;

        _monitors.Clear();
        _monitors.AddRange(MonitorService.GetMonitors());
        var active = AppServices.Engine.GetActiveAssignments();
        var paused = AppServices.Engine.IsUserPaused;

        var items = _monitors.Select(m =>
        {
            var hasWallpaper = active.TryGetValue(m.Id, out var wallpaperId);
            var wallpaperTitle = hasWallpaper
                ? (_installedItems.FirstOrDefault(w => w.Id == wallpaperId)?.Title ?? wallpaperId ?? "Bilinmiyor") +
                  (paused ? " (duraklatıldı)" : "")
                : "Atanmadı";

            return new MonitorListItem
            {
                Id = m.Id,
                Name = m.Name,
                Resolution = $"{m.Width} × {m.Height}",
                WallpaperTitle = wallpaperTitle,
                IsActive = hasWallpaper,
                IsPrimary = m.IsPrimary
            };
        }).ToList();

        MonitorRepeater.ItemsSource = items;

        // Uygula/Kaldir sonrasi SessionsChanged burayi cagirir; secim sifirlanmasin
        MonitorPicker.Items.Clear();
        foreach (var monitor in _monitors)
            MonitorPicker.Items.Add(monitor.Name);
        var keep = _monitors.FindIndex(m => m.Id == selectedMonitorId);
        MonitorPicker.SelectedIndex = keep >= 0 ? keep : (_monitors.Count > 0 ? 0 : -1);

        PauseAllSwitch.IsOn = paused;
    }

    private static WallpaperListItem ToWallpaperListItem(WallpaperManifest w) => new()
    {
        Id = w.Id,
        Title = w.Title,
        Type = w.Type,
        TypeLabel = WallpaperManifest.TypeLabel(w.Type),
        Version = $"v{w.Version}",
        Description = w.Description
    };

    private CatalogListItem ToCatalogListItem(CatalogEntry e) => new()
    {
        Id = e.Id,
        Title = e.Title,
        Type = e.Type,
        TypeLabel = WallpaperManifest.TypeLabel(e.Type),
        Version = _installedItems.Any(w => w.Id == e.Id) ? $"v{e.Version} · Kurulu" : $"v{e.Version}",
        Description = e.Description ?? "Açıklama yok"
    };

    private WallpaperManifest? GetSelectedInstalled() =>
        InstalledGrid.SelectedItem is WallpaperListItem item ? _installedItems.FirstOrDefault(w => w.Id == item.Id) : null;

    private CatalogEntry? GetSelectedCatalogEntry() =>
        CatalogGrid.SelectedItem is CatalogListItem item ? _catalogItems.FirstOrDefault(c => c.Id == item.Id) : null;

    private void InstalledGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is WallpaperListItem item)
            InstalledGrid.SelectedItem = item;
    }

    private void CatalogGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is CatalogListItem item)
            CatalogGrid.SelectedItem = item;
    }

    private void InstalledGrid_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e) => ApplyInstalled_Click(sender, e);

    private void CatalogGrid_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e) => DownloadCatalogItem_Click(sender, e);

    private void InstalledGrid_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter) { ApplyInstalled_Click(sender, e); e.Handled = true; }
        else if (e.Key == VirtualKey.Delete) { Uninstall_Click(sender, e); e.Handled = true; }
    }

    private void CatalogGrid_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter) { DownloadCatalogItem_Click(sender, e); e.Handled = true; }
    }

    private void Accelerator_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        switch (sender.Key)
        {
            case VirtualKey.Number1: Navigate(0); break;
            case VirtualKey.Number2: Navigate(1); break;
            case VirtualKey.Number3: Navigate(2); break;
            case VirtualKey.Number4: Navigate(3); break;
            case VirtualKey.F:
                Navigate(0);
                SearchBox.Focus(FocusState.Keyboard);
                SearchBox.SelectAll();
                break;
            case VirtualKey.O:
                Navigate(0);
                ImportFile_Click(this, new RoutedEventArgs());
                break;
            case VirtualKey.S:
                if (_currentTag == "settings") SaveSettings_Click(this, new RoutedEventArgs());
                else args.Handled = false;
                break;
            case VirtualKey.P:
                AppServices.Engine.IsUserPaused = !AppServices.Engine.IsUserPaused;
                break;
            case VirtualKey.F5:
                if (_currentTag == "catalog") LoadCatalog_Click(this, new RoutedEventArgs());
                else RefreshAll();
                break;
            default:
                args.Handled = false;
                break;
        }
    }

    private void GoToCatalog_Click(object sender, RoutedEventArgs e) => Navigate(1);

    private static void ShowInfo(InfoBar bar, string message, InfoBarSeverity severity = InfoBarSeverity.Informational)
    {
        bar.Message = message;
        bar.Severity = severity;
        bar.IsOpen = true;
    }

    private async void ApplyInstalled_Click(object sender, RoutedEventArgs e)
    {
        var manifest = GetSelectedInstalled();
        if (manifest == null)
        {
            ShowInfo(InstalledInfoBar, "Lütfen bir duvar kağıdı seçin.", InfoBarSeverity.Warning);
            return;
        }

        // Mesaj "birincil monitore" diyor; listenin ilk elemani birincil olmayabilir
        var monitor = _monitors.FirstOrDefault(m => m.IsPrimary) ?? _monitors.FirstOrDefault();
        if (monitor == null)
        {
            ShowInfo(InstalledInfoBar, "Monitör bulunamadı.", InfoBarSeverity.Error);
            return;
        }

        try
        {
            await AppServices.Engine.ApplyWallpaperAsync(monitor.Id, manifest.Id);
            ShowInfo(InstalledInfoBar, $"\"{manifest.Title}\" birincil monitöre uygulandı.", InfoBarSeverity.Success);
            RefreshMonitors();
        }
        catch (Exception ex)
        {
            ShowInfo(InstalledInfoBar, ex.Message, InfoBarSeverity.Error);
        }
    }

    private async void Uninstall_Click(object sender, RoutedEventArgs e)
    {
        var manifest = GetSelectedInstalled();
        if (manifest == null)
        {
            ShowInfo(InstalledInfoBar, "Lütfen bir duvar kağıdı seçin.", InfoBarSeverity.Warning);
            return;
        }

        if (_busy)
            return;
        _busy = true;
        try
        {
            // Kaldirma dosyalari siler; yanlislikla Delete'e basmak geri alinamaz olmasin
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot,
                Title = "Duvar kağıdı kaldırılsın mı?",
                Content = $"\"{manifest.Title}\" kütüphaneden ve diskten silinecek. Bu işlem geri alınamaz.",
                PrimaryButtonText = "Kaldır",
                CloseButtonText = "Vazgeç",
                DefaultButton = ContentDialogButton.Close
            };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary)
                return;

            // Aktif oynatici dosyalari kilitler (Image.FromFile); once masaustunden kaldir
            foreach (var (monitorId, wallpaperId) in AppServices.Engine.GetActiveAssignments())
            {
                if (wallpaperId == manifest.Id)
                    await AppServices.Engine.RemoveWallpaperAsync(monitorId);
            }

            AppServices.Installed.Uninstall(manifest.Id);
            ShowInfo(InstalledInfoBar, $"\"{manifest.Title}\" kaldırıldı.", InfoBarSeverity.Success);
        }
        catch (Exception ex)
        {
            ShowInfo(InstalledInfoBar, ex.Message, InfoBarSeverity.Error);
        }
        finally
        {
            _busy = false;
        }

        RefreshInstalled();
    }

    private void RefreshInstalled_Click(object sender, RoutedEventArgs e) => RefreshAll();

    private async void ImportFile_Click(object sender, RoutedEventArgs e)
    {
        if (_busy)
            return;
        _busy = true;
        try
        {
            var picker = new Microsoft.Windows.Storage.Pickers.FileOpenPicker(XamlRoot.ContentIslandEnvironment.AppWindowId);
            foreach (var ext in InstalledWallpaperService.ImportableExtensions.Keys)
                picker.FileTypeFilter.Add(ext);

            var files = await picker.PickMultipleFilesAsync();
            ImportFiles(files.Select(f => f.Path));
        }
        catch (Exception ex)
        {
            ShowInfo(InstalledInfoBar, ex.Message, InfoBarSeverity.Error);
        }
        finally
        {
            _busy = false;
        }
    }

    private void InstalledPanel_DragOver(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
            return;

        e.AcceptedOperation = Windows.ApplicationModel.DataTransfer.DataPackageOperation.Copy;
        e.DragUIOverride.Caption = "Kütüphaneye ekle";
    }

    private async void InstalledPanel_Drop(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
            return;

        try
        {
            var items = await e.DataView.GetStorageItemsAsync();
            ImportFiles(items.Select(i => i.Path));
        }
        catch (Exception ex)
        {
            ShowInfo(InstalledInfoBar, ex.Message, InfoBarSeverity.Error);
        }
    }

    private void ImportFiles(IEnumerable<string> paths)
    {
        var added = new List<string>();
        var errors = new List<string>();
        foreach (var path in paths)
        {
            try
            {
                added.Add(AppServices.Installed.ImportFile(path).Title);
            }
            catch (Exception ex)
            {
                errors.Add($"{Path.GetFileName(path)}: {ex.Message}");
            }
        }

        if (added.Count == 0 && errors.Count == 0)
            return; // secim iptal edildi

        RefreshInstalled();
        if (errors.Count == 0)
            ShowInfo(InstalledInfoBar, $"{added.Count} duvar kağıdı eklendi: {string.Join(", ", added)}", InfoBarSeverity.Success);
        else
            ShowInfo(InstalledInfoBar,
                $"{added.Count} eklendi, {errors.Count} eklenemedi. {string.Join(" | ", errors)}",
                added.Count > 0 ? InfoBarSeverity.Warning : InfoBarSeverity.Error);
    }

    private async void LoadCatalog_Click(object sender, RoutedEventArgs e)
    {
        _catalogLoadedOnce = true;
        CatalogLoadingRing.IsActive = true;
        CatalogLoadingRing.Visibility = Visibility.Visible;

        try
        {
            var settings = AppServices.Settings.Load();
            var index = await AppServices.Catalog.FetchIndexAsync(settings.CatalogUrl);
            _catalogItems.Clear();
            _catalogItems.AddRange(index.Wallpapers);
            ShowCatalogItems();
            ShowInfo(CatalogInfoBar, $"{_catalogItems.Count} duvar kağıdı yüklendi.", InfoBarSeverity.Success);
        }
        catch (Exception ex)
        {
            ShowInfo(CatalogInfoBar, ex.Message, InfoBarSeverity.Error);
        }
        finally
        {
            CatalogLoadingRing.IsActive = false;
            CatalogLoadingRing.Visibility = Visibility.Collapsed;
        }
    }

    private void ShowCatalogItems()
    {
        var selectedId = (CatalogGrid.SelectedItem as CatalogListItem)?.Id;
        var items = _catalogItems.Select(ToCatalogListItem).ToList();
        CatalogGrid.ItemsSource = items;
        CatalogGrid.SelectedItem = items.FirstOrDefault(i => i.Id == selectedId);
        CatalogEmpty.Visibility = items.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        CatalogGrid.Visibility = items.Count == 0 ? Visibility.Collapsed : Visibility.Visible;
    }

    private async void DownloadCatalogItem_Click(object sender, RoutedEventArgs e)
    {
        var entry = GetSelectedCatalogEntry();
        if (entry == null)
        {
            ShowInfo(CatalogInfoBar, "Lütfen katalogdan bir duvar kağıdı seçin.", InfoBarSeverity.Warning);
            return;
        }

        if (_busy)
            return;
        _busy = true;
        CatalogLoadingRing.IsActive = true;
        CatalogLoadingRing.Visibility = Visibility.Visible;

        try
        {
            var settings = AppServices.Settings.Load();
            var baseUrl = CatalogService.GetCatalogBaseUrl(settings.CatalogUrl);
            var manifest = await AppServices.Catalog.DownloadAndInstallAsync(entry, baseUrl);
            ShowInfo(CatalogInfoBar, $"\"{manifest.Title}\" kuruldu.", InfoBarSeverity.Success);
            RefreshInstalled();
            ShowCatalogItems(); // "Kurulu" etiketi guncellensin
        }
        catch (Exception ex)
        {
            ShowInfo(CatalogInfoBar, ex.Message, InfoBarSeverity.Error);
        }
        finally
        {
            _busy = false;
            CatalogLoadingRing.IsActive = false;
            CatalogLoadingRing.Visibility = Visibility.Collapsed;
        }
    }

    private async void ApplyMonitor_Click(object sender, RoutedEventArgs e)
    {
        if (MonitorPicker.SelectedIndex < 0 || WallpaperPicker.SelectedIndex < 0 ||
            MonitorPicker.SelectedIndex >= _monitors.Count || WallpaperPicker.SelectedIndex >= _installedItems.Count)
        {
            ShowInfo(MonitorInfoBar, "Monitör ve duvar kağıdı seçin.", InfoBarSeverity.Warning);
            return;
        }

        var monitor = _monitors[MonitorPicker.SelectedIndex];
        var wallpaper = _installedItems[WallpaperPicker.SelectedIndex];

        try
        {
            await AppServices.Engine.ApplyWallpaperAsync(monitor.Id, wallpaper.Id);
            ShowInfo(MonitorInfoBar, $"\"{wallpaper.Title}\" → {monitor.Name}", InfoBarSeverity.Success);
            RefreshMonitors();
        }
        catch (Exception ex)
        {
            ShowInfo(MonitorInfoBar, ex.Message, InfoBarSeverity.Error);
        }
    }

    private async void RemoveMonitor_Click(object sender, RoutedEventArgs e)
    {
        if (MonitorPicker.SelectedIndex < 0 || MonitorPicker.SelectedIndex >= _monitors.Count)
        {
            ShowInfo(MonitorInfoBar, "Monitör seçin.", InfoBarSeverity.Warning);
            return;
        }

        var monitor = _monitors[MonitorPicker.SelectedIndex];
        if (!AppServices.Engine.GetActiveAssignments().ContainsKey(monitor.Id))
        {
            ShowInfo(MonitorInfoBar, $"{monitor.Name} için atanmış duvar kağıdı yok.", InfoBarSeverity.Informational);
            return;
        }

        try
        {
            await AppServices.Engine.RemoveWallpaperAsync(monitor.Id);
            ShowInfo(MonitorInfoBar, $"{monitor.Name} için duvar kağıdı kaldırıldı.", InfoBarSeverity.Success);
        }
        catch (Exception ex)
        {
            ShowInfo(MonitorInfoBar, ex.Message, InfoBarSeverity.Error);
        }

        RefreshMonitors();
    }

    private void PauseAllSwitch_Toggled(object sender, RoutedEventArgs e) =>
        AppServices.Engine.IsUserPaused = PauseAllSwitch.IsOn;

    // Olay isleyicilerindeki yakalanmayan istisna WinUI uygulamasini kapatir; hepsi InfoBar'a duser
    private void SaveSettings_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var url = string.IsNullOrWhiteSpace(CatalogUrlBox.Text) ? CatalogUrlResolver.BundledToken : CatalogUrlBox.Text.Trim();
            if (!CatalogUrlResolver.IsValidSetting(url))
            {
                ShowInfo(SettingsInfoBar, "Katalog URL geçersiz. \"bundled\", http(s):// adresi ya da yerel dosya yolu girin.", InfoBarSeverity.Error);
                return;
            }

            var settings = AppServices.Settings.Load();
            var catalogChanged = settings.CatalogUrl != url;
            settings.CatalogUrl = url;
            settings.RunAtStartup = RunAtStartupSwitch.IsOn;
            settings.PauseOnFullscreen = PauseFullscreenSwitch.IsOn;

            AppServices.Settings.Save(settings);
            StartupService.SetRunAtStartup(settings.RunAtStartup);
            CatalogUrlBox.Text = url;
            if (catalogChanged)
                _catalogLoadedOnce = false; // Magaza bir sonraki acilista yeni adresten yuklensin
            ShowInfo(SettingsInfoBar, "Ayarlar kaydedildi.", InfoBarSeverity.Success);
        }
        catch (Exception ex)
        {
            ShowInfo(SettingsInfoBar, $"Ayarlar kaydedilemedi: {ex.Message}", InfoBarSeverity.Error);
        }
    }

    private void ClearCache_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (Directory.Exists(AppServices.Paths.Cache))
                Directory.Delete(AppServices.Paths.Cache, recursive: true);
            Directory.CreateDirectory(AppServices.Paths.Cache);
            ShowInfo(SettingsInfoBar, "Önbellek temizlendi.", InfoBarSeverity.Success);
        }
        catch (Exception ex)
        {
            ShowInfo(SettingsInfoBar, $"Önbellek temizlenemedi (dosya kullanımda olabilir): {ex.Message}", InfoBarSeverity.Error);
        }
    }
}
