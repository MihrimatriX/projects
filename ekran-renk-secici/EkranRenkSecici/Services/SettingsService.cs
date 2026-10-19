using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using EkranRenkSecici.Models;

namespace EkranRenkSecici.Services;

public sealed class SettingsService
{
    // EKRAN_RENK_SECICI_DATA_DIR: testler gercek kullanici ayar/gecmisine dokunmasin diye.
    public static SettingsService Instance { get; } = new(
        Environment.GetEnvironmentVariable("EKRAN_RENK_SECICI_DATA_DIR") is { Length: > 0 } dir
            ? dir
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "EkranRenkSecici"));

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly string _settingsPath;
    private readonly string _historyPath;

    public AppSettings Current { get; private set; } = new();

    public event Action? SettingsChanged;

    internal SettingsService(string folder)
    {
        Directory.CreateDirectory(folder);
        _settingsPath = Path.Combine(folder, "settings.json");
        _historyPath = Path.Combine(folder, "history.json");
        Load();
    }

    public void Load()
    {
        try
        {
            if (!File.Exists(_settingsPath))
            {
                Current = new AppSettings();
                return;
            }

            var json = File.ReadAllText(_settingsPath);
            Current = JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
            Normalize();
        }
        catch
        {
            Current = new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        Current = settings;
        Normalize();
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(Current, JsonOptions));
        SettingsChanged?.Invoke();
    }

    /// <summary>Son yakalanan renkler (HEX, en yeni once). Bozuk/eksik dosyada bos liste.</summary>
    public List<string> LoadHistory()
    {
        try
        {
            return File.Exists(_historyPath)
                ? JsonSerializer.Deserialize<List<string>>(File.ReadAllText(_historyPath)) ?? []
                : [];
        }
        catch
        {
            return [];
        }
    }

    public void SaveHistory(IEnumerable<string> hexColors)
    {
        try
        {
            File.WriteAllText(_historyPath, JsonSerializer.Serialize(hexColors));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Gecmis kaydi kritik degil; disk/izin sorununda uygulama calismaya devam eder.
        }
    }

    private void Normalize()
    {
        if (Current.SampleSize is not (1 or 3 or 5)) Current.SampleSize = 3;
        Current.MagnifierZoom = Math.Clamp(Current.MagnifierZoom, 4, 16);
    }
}
