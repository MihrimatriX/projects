namespace SistemYoneticisi.Services;

public sealed class AlarmService
{
    private int _cpuHighSeconds;
    private int _ramHighSeconds;
    private bool _cpuAlarmFired;
    private bool _ramAlarmFired;

    public event Action<string, string>? AlarmTriggered;

    public void Evaluate(double cpu, double ram)
    {
        var settings = SettingsService.Instance.Settings;
        if (!settings.AlarmsEnabled) return;

        EvaluateMetric(cpu, settings.CpuAlarmThreshold, settings.AlarmDurationSeconds,
            ref _cpuHighSeconds, ref _cpuAlarmFired, "CPU", "işlemci");

        EvaluateMetric(ram, settings.RamAlarmThreshold, settings.AlarmDurationSeconds,
            ref _ramHighSeconds, ref _ramAlarmFired, "RAM", "bellek");
    }

    private void EvaluateMetric(double value, double threshold, int durationSeconds,
        ref int highSeconds, ref bool alarmFired, string label, string labelTr)
    {
        if (value >= threshold)
        {
            highSeconds++;
            if (!alarmFired && highSeconds >= durationSeconds)
            {
                alarmFired = true;
                AlarmTriggered?.Invoke(
                    $"{label} alarmı",
                    $"{labelTr} kullanımı %{threshold:F0} eşiğini {durationSeconds} saniyeden uzun süredir aşıyor (şu an %{value:F0}).");
            }
        }
        else
        {
            highSeconds = 0;
            alarmFired = false;
        }
    }
}
