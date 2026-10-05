using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranRenkSecici.Helpers;
using EkranRenkSecici.Models;
using EkranRenkSecici.Services;
using EkranRenkSecici.Views;
using NHotkey.Wpf;

namespace EkranRenkSecici.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty] private ColorItem? _selectedColor;
    [ObservableProperty] private ColorItem? _complementaryColor;
    [ObservableProperty] private ColorItem? _contrastForeground;
    [ObservableProperty] private ColorItem? _contrastBackground;
    [ObservableProperty] private string _contrastRatioText = "—";
    [ObservableProperty] private string _contrastNormalStatus = "Normal metin: —";
    [ObservableProperty] private string _contrastLargeStatus = "Büyük metin: —";
    [ObservableProperty] private string _statusMessage = "Hazır — Ctrl+Shift+C ile renk seçin";
    [ObservableProperty] private string _hotkeyDisplay = "Ctrl+Shift+C";
    [ObservableProperty] private ContrastBgMode _contrastBgMode = ContrastBgMode.White;
    [ObservableProperty] private ColorHelper.ColorBlindnessType _colorBlindnessType = ColorHelper.ColorBlindnessType.None;
    [ObservableProperty] private string _colorInput = string.Empty;

    public ObservableCollection<ColorItem> History { get; } = new();
    public ObservableCollection<ColorItem> AnalogousPalette { get; } = new();
    public ObservableCollection<ColorItem> ColorBlindPreview { get; } = new();

    public event Action? RequestMainWindowShow;

    public MainViewModel()
    {
        SettingsService.Instance.SettingsChanged += OnSettingsChanged;

        foreach (var hex in SettingsService.Instance.LoadHistory())
        {
            if (History.Count < 10 && ColorHelper.TryParse(hex, out var c))
                History.Add(new ColorItem(c));
        }

        OnSettingsChanged();
    }

    private void OnSettingsChanged()
    {
        UpdateHotkeyDisplay();
        StatusMessage = RegisterHotkey()
            ? $"Hazır — {HotkeyDisplay} ile renk seçin"
            : $"⚠ {HotkeyDisplay} kısayolu kaydedilemedi (başka uygulama kullanıyor olabilir) — Ayarlar'dan değiştirin";
    }

    private bool RegisterHotkey()
    {
        try
        {
            try { HotkeyManager.Current.Remove("CaptureColor"); } catch { /* first run */ }
            var s = SettingsService.Instance.Current;
            HotkeyManager.Current.AddOrReplace(
                "CaptureColor",
                HotkeyHelper.ParseKey(s.HotkeyKey),
                HotkeyHelper.ParseModifiers(s.HotkeyModifiers),
                (_, e) => { StartCapture(); e.Handled = true; });
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Hotkey: {ex.Message}");
            return false;
        }
    }

    private void UpdateHotkeyDisplay()
    {
        var s = SettingsService.Instance.Current;
        HotkeyDisplay = HotkeyHelper.FormatDisplay(s.HotkeyModifiers, s.HotkeyKey);
    }

    private bool _capturing;

    [RelayCommand]
    private void StartCapture()
    {
        // ShowDialog mesaj döngüsü çalıştırdığı için kısayol overlay açıkken tekrar tetiklenebilir;
        // ikinci bir overlay açılmasın.
        if (_capturing) return;
        _capturing = true;
        try
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                var win = new SelectionWindow(History.Select(h => h.Value).ToList());
                win.ColorSelected += OnColorCaptured;
                win.ShowDialog();
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Renk seçimi açılamadı:\n{ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            _capturing = false;
        }
    }

    private void OnColorCaptured(Color color)
    {
        AddColorToHistory(color);
        // Panoya kopyalama overlay'de, kullanıcının orada seçtiği formatla zaten yapıldı.
        StatusMessage = $"{ColorHelper.ToHex(color)} panoya kopyalandı";
    }

    private void AddColorToHistory(Color color)
    {
        var hex = ColorHelper.ToHex(color);
        for (int i = 0; i < History.Count; i++)
        {
            if (History[i].Hex == hex) { History.RemoveAt(i); break; }
        }

        var item = new ColorItem(color);
        History.Insert(0, item);
        while (History.Count > 10) History.RemoveAt(History.Count - 1);
        SelectedColor = item;
        SettingsService.Instance.SaveHistory(History.Select(h => h.Hex));
    }

    /// <summary>Elle girilen HEX / rgb() rengini secer ve gecmise ekler.</summary>
    [RelayCommand]
    private void ApplyColorInput()
    {
        if (!ColorHelper.TryParse(ColorInput, out var color))
        {
            StatusMessage = "Geçersiz renk — örn. #3B82F6, #38F veya rgb(59, 130, 246)";
            return;
        }

        AddColorToHistory(color);
        ColorInput = string.Empty;
    }

    partial void OnSelectedColorChanged(ColorItem? value) => RefreshColorDetails();

    partial void OnContrastBgModeChanged(ContrastBgMode value) => UpdateContrast();

    partial void OnColorBlindnessTypeChanged(ColorHelper.ColorBlindnessType value) => UpdateColorBlindPreview();

    [RelayCommand]
    private void SetContrastBg(string? mode)
    {
        if (mode != null && Enum.TryParse<ContrastBgMode>(mode, out var m))
            ContrastBgMode = m;
    }

    [RelayCommand]
    private void SetColorBlindness(string? type)
    {
        if (type != null && Enum.TryParse<ColorHelper.ColorBlindnessType>(type, out var t))
            ColorBlindnessType = t;
    }

    private void RefreshColorDetails()
    {
        if (SelectedColor == null)
        {
            ComplementaryColor = null;
            AnalogousPalette.Clear();
            ColorBlindPreview.Clear();
            ContrastRatioText = "—";
            ContrastNormalStatus = "Normal metin: —";
            ContrastLargeStatus = "Büyük metin: —";
            return;
        }

        ComplementaryColor = new ColorItem(ColorHelper.GetComplementary(SelectedColor.Value));
        AnalogousPalette.Clear();
        foreach (var c in ColorHelper.GetAnalogous(SelectedColor.Value))
            AnalogousPalette.Add(new ColorItem(c));

        UpdateContrast();
        UpdateColorBlindPreview();
        StatusMessage = $"Seçili: {SelectedColor.Hex}";
    }

    private void UpdateContrast()
    {
        if (SelectedColor == null) return;

        var fg = SelectedColor.Value;
        var bg = ContrastBgMode switch
        {
            ContrastBgMode.Dark => Color.FromRgb(0x16, 0x16, 0x18),
            ContrastBgMode.Complementary => ComplementaryColor?.Value ?? Colors.White,
            _ => Colors.White
        };

        ContrastForeground = new ColorItem(fg);
        ContrastBackground = new ColorItem(bg);

        var ratio = ColorHelper.GetContrastRatio(fg, bg);
        ContrastRatioText = ColorHelper.FormatContrastRatio(ratio);
        ContrastNormalStatus = $"Normal metin: {ColorHelper.GetWcagNormalTextStatus(ratio)}";
        ContrastLargeStatus = $"Büyük metin: {ColorHelper.GetWcagLargeTextStatus(ratio)}";
    }

    private void UpdateColorBlindPreview()
    {
        if (SelectedColor == null) return;

        ColorBlindPreview.Clear();
        var sources = new[] { SelectedColor.Value }
            .Concat(ColorHelper.GetExportPalette(SelectedColor.Value).Take(3))
            .Take(4);

        foreach (var c in sources)
            ColorBlindPreview.Add(new ColorItem(ColorHelper.SimulateColorBlindness(c, ColorBlindnessType)));
    }

    [RelayCommand]
    private void CopyFormat(CopyFormat format)
    {
        if (SelectedColor == null) return;
        CopyToClipboard(SelectedColor.Format(format), format.ToString());
    }

    [RelayCommand]
    private void CopySpecificColor(ColorItem? item)
    {
        if (item == null) return;
        CopyToClipboard(item.Hex, "HEX");
    }

    [RelayCommand]
    private void OpenExport()
    {
        if (SelectedColor == null) return;
        RequestMainWindowShow?.Invoke();
        new ExportWindow(SelectedColor.Value) { Owner = Application.Current.MainWindow }.ShowDialog();
    }

    private void CopyToClipboard(string text, string label)
    {
        try
        {
            Clipboard.SetText(text);
            StatusMessage = $"{label} panoya kopyalandı";
        }
        catch { /* clipboard busy */ }
    }

    [RelayCommand]
    private void ClearHistory()
    {
        History.Clear();
        SelectedColor = null;
        SettingsService.Instance.SaveHistory([]);
        StatusMessage = "Geçmiş temizlendi";
    }

    [RelayCommand]
    private void OpenSettings()
    {
        RequestMainWindowShow?.Invoke();
        new SettingsWindow { Owner = Application.Current.MainWindow }.ShowDialog();
    }

    [RelayCommand]
    private void ShowMainWindow() => RequestMainWindowShow?.Invoke();

    [RelayCommand]
    private void Exit()
    {
        if (Application.Current.MainWindow is MainWindow main) main.PrepareForExit();
        Application.Current.Shutdown();
    }
}

public enum ContrastBgMode { White, Dark, Complementary }
