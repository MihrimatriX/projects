using EkranZamani.Helpers;
using EkranZamani.Services;
using Microsoft.UI.Dispatching;

namespace EkranZamani_WinUI.Services;

public sealed class AppTracking
{
    public static AppTracking Instance { get; } = new();

    private TrackingService? _tracking;
    public TrackingService Tracking => _tracking ??= new TrackingService(AppServices.Database);

    public bool IsTracking { get; private set; } = true;
    public string StatusText { get; private set; } = "İzleniyor";
    public string ActiveAppText { get; private set; } = "—";

    public event Action? Changed;

    private DispatcherQueue? _dispatcher;

    public void Bind(DispatcherQueue dispatcher)
    {
        if (_dispatcher != null) return;
        _dispatcher = dispatcher;
        Tracking.Ticked += OnTicked;
        Tracking.ActiveAppChanged += () => _dispatcher.TryEnqueue(Notify);
        Tracking.Start();
    }

    private void OnTicked(string processName, int elapsedSec)
    {
        _dispatcher?.TryEnqueue(() =>
        {
            if (!IsTracking) return;
            var name = ProcessDisplayNames.GetFriendlyName(processName);
            ActiveAppText = elapsedSec > 0 ? $"{name} · {elapsedSec} sn" : name;
            Notify();
        });
    }

    public void SetTracking(bool enabled)
    {
        IsTracking = enabled;
        if (enabled)
        {
            Tracking.Start();
            StatusText = "İzleniyor";
        }
        else
        {
            Tracking.Stop();
            StatusText = "Duraklatıldı";
            ActiveAppText = "Duraklatıldı";
        }
        Notify();
    }

    public void Toggle() => SetTracking(!IsTracking);

    private void Notify() => Changed?.Invoke();
}
