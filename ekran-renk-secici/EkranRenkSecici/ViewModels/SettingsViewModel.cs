using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EkranRenkSecici.Helpers;
using EkranRenkSecici.Models;
using EkranRenkSecici.Services;
using NHotkey.Wpf;

namespace EkranRenkSecici.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    [ObservableProperty] private string _hotkeyKey = "C";
    [ObservableProperty] private bool _modifierControl = true;
    [ObservableProperty] private bool _modifierShift = true;
    [ObservableProperty] private bool _modifierAlt;
    [ObservableProperty] private CopyFormat _defaultCopyFormat = CopyFormat.HEX;
    [ObservableProperty] private int _sampleSize = 3;
    [ObservableProperty] private int _magnifierZoom = 8;
    [ObservableProperty] private bool _hasHotkeyConflict;

    public IReadOnlyList<string> HotkeyKeys { get; } =
        Enumerable.Range(0, 26).Select(i => ((char)('A' + i)).ToString()).ToList();

    public IReadOnlyList<CopyFormat> CopyFormats { get; } = Enum.GetValues<CopyFormat>();
    public int[] SampleSizes { get; } = [1, 3, 5];

    public event Action<bool>? RequestClose;

    public SettingsViewModel()
    {
        LoadFromService();
        CheckHotkeyConflict();
    }

    partial void OnHotkeyKeyChanged(string value) => CheckHotkeyConflict();
    partial void OnModifierControlChanged(bool value) => CheckHotkeyConflict();
    partial void OnModifierShiftChanged(bool value) => CheckHotkeyConflict();
    partial void OnModifierAltChanged(bool value) => CheckHotkeyConflict();

    private void LoadFromService()
    {
        var s = SettingsService.Instance.Current;
        HotkeyKey = s.HotkeyKey;
        DefaultCopyFormat = s.DefaultCopyFormat;
        SampleSize = s.SampleSize;
        MagnifierZoom = s.MagnifierZoom;

        var mods = s.HotkeyModifiers.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        ModifierControl = mods.Contains("Control", StringComparer.OrdinalIgnoreCase);
        ModifierShift = mods.Contains("Shift", StringComparer.OrdinalIgnoreCase);
        ModifierAlt = mods.Contains("Alt", StringComparer.OrdinalIgnoreCase);
    }

    private void CheckHotkeyConflict()
    {
        // Mevcut kısayol bu uygulama tarafından zaten kayıtlı; deneme kaydı onu çakışma sanmasın.
        var current = SettingsService.Instance.Current;
        if (HotkeyHelper.ParseKey(HotkeyKey) == HotkeyHelper.ParseKey(current.HotkeyKey) &&
            HotkeyHelper.ParseModifiers(BuildModifiers()) == HotkeyHelper.ParseModifiers(current.HotkeyModifiers))
        {
            HasHotkeyConflict = false;
            return;
        }

        // Çakışma testi: kısayolu geçici olarak kaydetmeyi dener; başka uygulama tutuyorsa istisna fırlar.
        try
        {
            try { HotkeyManager.Current.Remove("HotkeyProbe"); } catch { /* ok */ }
            var mods = HotkeyHelper.ParseModifiers(BuildModifiers());
            HotkeyManager.Current.AddOrReplace(
                "HotkeyProbe",
                HotkeyHelper.ParseKey(HotkeyKey),
                mods,
                (_, _) => { });
            HotkeyManager.Current.Remove("HotkeyProbe");
            HasHotkeyConflict = false;
        }
        catch
        {
            HasHotkeyConflict = true;
        }
    }

    private string BuildModifiers()
    {
        var mods = new List<string>();
        if (ModifierControl) mods.Add("Control");
        if (ModifierShift) mods.Add("Shift");
        if (ModifierAlt) mods.Add("Alt");
        if (mods.Count == 0) mods.Add("Control");
        return string.Join(",", mods);
    }

    [RelayCommand]
    private void Save()
    {
        SettingsService.Instance.Save(new AppSettings
        {
            HotkeyKey = HotkeyKey,
            HotkeyModifiers = BuildModifiers(),
            DefaultCopyFormat = DefaultCopyFormat,
            SampleSize = SampleSize is 3 or 5 ? SampleSize : 1,
            MagnifierZoom = Math.Clamp(MagnifierZoom, 4, 16)
        });
        RequestClose?.Invoke(true);
    }

    [RelayCommand]
    private void Cancel() => RequestClose?.Invoke(false);
}
