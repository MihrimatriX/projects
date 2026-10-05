using EkranZamani.Services;
using EkranZamani_WinUI.ViewModels;

namespace EkranZamani_WinUI.Services;

public static class WinUiAppHost
{
    public static WinUiHotkeyService Hotkeys { get; } = new();

    public static void Configure(MainWindow window, WinUiTrayService tray, DailyPageViewModel dailyVm)
    {
        AppServices.DailySummaryReady += message =>
            tray.ShowBalloon("Gün özeti", message);

        AppServices.UsageAlerts.DistractingLimitExceeded += minutes =>
            tray.ShowBalloon("Dikkat süresi", $"Bugün dikkat dağıtıcı süre {minutes} dakikayı aştı.");

        AppServices.FocusGoals.GoalCompleted += goal =>
            tray.ShowBalloon("Hedef tamamlandı", $"{goal.Title} — {goal.TargetMinutes} dk");

        if (AppServices.Settings.Current.EnableGlobalHotkey)
        {
            App.DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () =>
                Hotkeys.Register(window.ShowFromTray));
        }
    }

    public static void RefreshHotkey(bool enabled, Action showWindow)
    {
        Hotkeys.Unregister();
        if (enabled)
            Hotkeys.Register(showWindow);
    }

    public static void Shutdown() => Hotkeys.Dispose();
}
