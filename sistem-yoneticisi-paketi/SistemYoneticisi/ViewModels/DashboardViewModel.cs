using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using LiveChartsCore;
using LiveChartsCore.Defaults;
using LiveChartsCore.SkiaSharpView;
using LiveChartsCore.SkiaSharpView.Painting;
using Microsoft.Win32;
using SkiaSharp;
using SistemYoneticisi.Helpers;
using SistemYoneticisi.Services;

namespace SistemYoneticisi.ViewModels;

public partial class DashboardViewModel : ObservableObject
{
    private readonly SystemInfoService _sysInfo;
    private readonly ProcessService? _processes;
    private readonly MetricsHistoryService? _history;
    private readonly AlarmService? _alarm;
    private readonly MainViewModel _mainVm;
    private readonly DispatcherTimer _timer;
    private int _historyPruneCounter;
    private int _processRefreshCounter;

    [ObservableProperty]
    private double _cpuPercentage;

    [ObservableProperty]
    private double _ramPercentage;

    [ObservableProperty]
    private string _ramText = "0 / 0 GB";

    [ObservableProperty]
    private string _networkText = "↓ 0 Kbps | ↑ 0 Kbps";

    [ObservableProperty]
    private string _networkShortText = "0 Kbps";

    [ObservableProperty]
    private double _primaryDiskUsage;

    [ObservableProperty]
    private string _primaryDiskLabel = "Disk";

    [ObservableProperty]
    private string _primaryDiskSubText = string.Empty;

    [ObservableProperty]
    private string _cpuSubText = string.Empty;

    [ObservableProperty]
    private bool _isAlarmBannerVisible;

    [ObservableProperty]
    private bool _isPaused;

    [ObservableProperty]
    private string _pauseButtonText = "⏸ Duraklat";

    [ObservableProperty]
    private bool _isCpuWarning;

    [ObservableProperty]
    private bool _isRamWarning;

    [ObservableProperty]
    private bool _isPausedBannerVisible;

    [ObservableProperty]
    private bool _showHistoryChart;

    [ObservableProperty]
    private string _historyStatusText = "Geçmiş kapalı — Ayarlardan etkinleştirin";

    public ObservableCollection<DiskDriveInfo> Disks { get; } = new();
    public ObservableCollection<ProcessInfo> TopProcesses { get; } = new();
    public ObservableCollection<ObservableValue> CpuHistory { get; } = new();
    public ObservableCollection<ObservableValue> RamHistory { get; } = new();

    public ISeries[] CpuSeries { get; }
    public ISeries[] RamSeries { get; }
    public Axis[] XAxes { get; }
    public Axis[] YAxes { get; }

    public event Action<double, double>? MetricsUpdated;

    public DashboardViewModel(
        SystemInfoService sysInfo,
        MainViewModel mainVm,
        MetricsHistoryService? history = null,
        AlarmService? alarm = null,
        ProcessService? processes = null)
    {
        _sysInfo = sysInfo;
        _mainVm = mainVm;
        _history = history;
        _alarm = alarm;
        _processes = processes;

        for (var i = 0; i < 30; i++)
        {
            CpuHistory.Add(new ObservableValue(0));
            RamHistory.Add(new ObservableValue(0));
        }

        var cpuColor = new SKColor(59, 130, 246);
        var ramColor = new SKColor(139, 92, 246);

        CpuSeries = new ISeries[]
        {
            new LineSeries<ObservableValue>
            {
                Values = CpuHistory,
                Name = "CPU",
                Stroke = new SolidColorPaint(cpuColor, 3),
                GeometrySize = 0,
                Fill = new SolidColorPaint(cpuColor.WithAlpha(30))
            }
        };

        RamSeries = new ISeries[]
        {
            new LineSeries<ObservableValue>
            {
                Values = RamHistory,
                Name = "Bellek",
                Stroke = new SolidColorPaint(ramColor, 3),
                GeometrySize = 0,
                Fill = new SolidColorPaint(ramColor.WithAlpha(30))
            }
        };

        XAxes = new Axis[] { new Axis { IsVisible = false } };
        YAxes = new Axis[]
        {
            new Axis
            {
                MinLimit = 0,
                MaxLimit = 100,
                Labeler = val => $"{val}%",
                LabelsPaint = new SolidColorPaint(new SKColor(107, 114, 128))
            }
        };

        UpdateHistoryStatus();

        // DispatcherTimer UI iş parçacığında çalışır; koleksiyonlar güvenle güncellenir.
        // Her tik: metrikleri oku, geçmişe yaz (açıksa), alarmı değerlendir.
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += Timer_Tick;
        _timer.Start();

        UpdateMetrics();
    }

    [RelayCommand]
    private void TogglePause()
    {
        IsPaused = !IsPaused;
        PauseButtonText = IsPaused ? "▶ Devam Et" : "⏸ Duraklat";
    }

    partial void OnIsPausedChanged(bool value) => IsPausedBannerVisible = value;

    partial void OnIsRamWarningChanged(bool value) => IsAlarmBannerVisible = value && !IsAlarmDismissed;

    private bool IsAlarmDismissed;

    [RelayCommand]
    private void DismissAlarm()
    {
        IsAlarmDismissed = true;
        IsAlarmBannerVisible = false;
    }

    [RelayCommand]
    private void RefreshNow() => UpdateMetrics();

    [RelayCommand]
    private void ToggleHistoryChart()
    {
        if (!SettingsService.Instance.Settings.HistoryEnabled)
        {
            _mainVm.StatusMessage = "24 saat geçmişi kullanmak için Ayarlar'dan etkinleştirin";
            return;
        }

        ShowHistoryChart = !ShowHistoryChart;
        if (ShowHistoryChart)
            LoadHistoryChart();
        else
            ResetLiveChart();
    }

    [RelayCommand]
    private void ExportHistoryCsv()
    {
        if (_history == null || !SettingsService.Instance.Settings.HistoryEnabled)
        {
            _mainVm.StatusMessage = "Geçmiş kaydı kapalı";
            return;
        }

        var dialog = new SaveFileDialog
        {
            Filter = "CSV dosyası|*.csv",
            FileName = $"sistem-metrikleri-{DateTime.Now:yyyyMMdd-HHmm}.csv"
        };

        if (dialog.ShowDialog() != true) return;

        try
        {
            _history.ExportCsv(dialog.FileName, SettingsService.Instance.Settings.HistoryRetentionHours);
            _mainVm.StatusMessage = $"CSV dışa aktarıldı: {Path.GetFileName(dialog.FileName)}";
        }
        catch (Exception ex)
        {
            LogService.Error("CSV export failed", ex);
            _mainVm.StatusMessage = "CSV dışa aktarılamadı";
        }
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        if (!IsPaused)
            UpdateMetrics();
    }

    private void UpdateMetrics()
    {
        CpuPercentage = _sysInfo.GetCpuUsage();
        IsCpuWarning = CpuPercentage >= 85;
        CpuSubText = $"{Environment.ProcessorCount} çekirdek";

        if (!ShowHistoryChart)
        {
            CpuHistory.Add(new ObservableValue(CpuPercentage));
            if (CpuHistory.Count > 30) CpuHistory.RemoveAt(0);
        }

        var ram = _sysInfo.GetRamUsage();
        RamPercentage = ram.UsagePercentage;
        IsRamWarning = RamPercentage >= 85;
        RamText = $"{ram.UsedGb:F1} GB / {ram.TotalGb:F1} GB ({RamPercentage}%)";

        if (!ShowHistoryChart)
        {
            RamHistory.Add(new ObservableValue(RamPercentage));
            if (RamHistory.Count > 30) RamHistory.RemoveAt(0);
        }

        var net = _sysInfo.GetNetworkSpeed();
        NetworkText = $"↓ {FormatHelpers.FormatSpeed(net.DownloadKbps)} | ↑ {FormatHelpers.FormatSpeed(net.UploadKbps)}";
        NetworkShortText = FormatHelpers.FormatSpeed(Math.Max(net.DownloadKbps, net.UploadKbps));

        Disks.Clear();
        foreach (var d in _sysInfo.GetDiskDrives())
            Disks.Add(d);

        var primary = Disks.FirstOrDefault();
        if (primary != null)
        {
            PrimaryDiskUsage = primary.UsagePercentage;
            PrimaryDiskLabel = $"Disk {primary.Name.TrimEnd('\\', ':')}:";
            PrimaryDiskSubText = $"{primary.FreeGb:F0} GB boş";
        }

        if (_processes != null && ++_processRefreshCounter % 3 == 0)
        {
            TopProcesses.Clear();
            foreach (var p in _processes.GetProcesses().OrderByDescending(x => x.CpuPercentage).Take(4))
                TopProcesses.Add(p);
        }

        var settings = SettingsService.Instance.Settings;
        if (settings.HistoryEnabled && _history != null)
        {
            _history.RecordSample(CpuPercentage, RamPercentage);
            if (++_historyPruneCounter >= 60)
            {
                _historyPruneCounter = 0;
                _history.PruneOlderThanHours(settings.HistoryRetentionHours);
            }
        }

        _alarm?.Evaluate(CpuPercentage, RamPercentage);
        MetricsUpdated?.Invoke(CpuPercentage, RamPercentage);

        if (ShowHistoryChart && settings.HistoryEnabled)
            LoadHistoryChart();
    }

    public void UpdateHistoryStatus()
    {
        var enabled = SettingsService.Instance.Settings.HistoryEnabled;
        HistoryStatusText = enabled
            ? $"24 saat geçmiş aktif ({SettingsService.Instance.Settings.HistoryRetentionHours} saat saklama)"
            : "Geçmiş kapalı — Ayarlardan etkinleştirin";
    }

    private void LoadHistoryChart()
    {
        if (_history == null) return;

        var samples = _history.GetRecentMinutes(60);
        if (samples.Count == 0) return;

        CpuHistory.Clear();
        RamHistory.Clear();
        foreach (var s in samples)
        {
            CpuHistory.Add(new ObservableValue(s.Cpu));
            RamHistory.Add(new ObservableValue(s.Ram));
        }
    }

    private void ResetLiveChart()
    {
        CpuHistory.Clear();
        RamHistory.Clear();
        for (var i = 0; i < 30; i++)
        {
            CpuHistory.Add(new ObservableValue(0));
            RamHistory.Add(new ObservableValue(0));
        }
    }
}
