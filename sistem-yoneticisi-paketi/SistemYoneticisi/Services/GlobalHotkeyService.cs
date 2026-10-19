using System;
using System.Windows.Input;
using NHotkey;
using NHotkey.Wpf;
using SistemYoneticisi.Helpers;

namespace SistemYoneticisi.Services;

public sealed class GlobalHotkeyService : IDisposable
{
    private const string HotkeyName = "ShowSistemMonitor";

    public event Action? HotkeyPressed;

    public bool Register(AppSettings settings)
    {
        Unregister();

        if (!settings.GlobalHotkeyEnabled)
            return true;

        if (!HotkeyParser.TryParse(settings.ShowHotkey, out var key, out var mods))
        {
            LogService.Info($"Invalid hotkey: {settings.ShowHotkey}");
            return false;
        }

        try
        {
            HotkeyManager.Current.AddOrReplace(HotkeyName, key, mods, OnHotkey);
            return true;
        }
        catch (Exception ex)
        {
            LogService.Error("Hotkey registration failed", ex);
            return false;
        }
    }

    public void Unregister()
    {
        try
        {
            HotkeyManager.Current.Remove(HotkeyName);
        }
        catch
        {
            // Best effort when hotkey was never registered.
        }
    }

    private void OnHotkey(object? sender, HotkeyEventArgs e) => HotkeyPressed?.Invoke();

    public void Dispose() => Unregister();
}
