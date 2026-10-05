using System;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Input;
using InputSimulatorStandard.Native;
using OtomasyonMakro.Helpers;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    /// <summary>
    /// Adımları sırayla yürütür. Acil durdurma: çağıran, <see cref="EmergencyStopMonitor"/> ile ESC'de
    /// iptal edilen bir token verir; bekleme adımları dahil her noktada anında durur.
    /// </summary>
    public class PlaybackService : IDisposable
    {
        private readonly IMacroInput _input;

        public PlaybackService() : this(new DesktopInput()) { }

        public PlaybackService(IMacroInput input)
        {
            _input = input;
        }

        public event Action<int>? OnStepStarted;
        public event Action<int>? OnIterationStarted;
        public event Action? OnFinished;
        public event Action? OnCancelled;
        public event Action<string>? OnError;

        public async Task PlayAsync(MacroProfile profile, CancellationToken cancellationToken)
        {
            int repeat = Math.Max(0, profile.RepeatCount); // 0 = durdurulana kadar
            for (int iteration = 1; profile.Steps.Count > 0 && (repeat == 0 || iteration <= repeat); iteration++)
            {
                if (iteration > 1)
                {
                    // Turlar arasında UI'ya nefes aldır; bekleme içermeyen sonsuz döngü de durdurulabilsin
                    try { await Task.Delay(1, cancellationToken); }
                    catch (OperationCanceledException) { OnCancelled?.Invoke(); return; }
                }

                OnIterationStarted?.Invoke(iteration);
                if (!await PlayRangeAsync(profile, 0, profile.Steps.Count, cancellationToken))
                    return;
            }

            OnFinished?.Invoke();
        }

        public async Task PlayStepAsync(MacroProfile profile, int stepIndex, CancellationToken cancellationToken)
        {
            if (stepIndex < 0 || stepIndex >= profile.Steps.Count) return;
            await PlayRangeAsync(profile, stepIndex, stepIndex + 1, cancellationToken);
        }

        /// <returns>false: iptal edildi ya da hata oluştu (olay zaten bildirildi).</returns>
        private async Task<bool> PlayRangeAsync(MacroProfile profile, int startIndex, int endIndexExclusive, CancellationToken cancellationToken)
        {
            try
            {
                int i = startIndex;
                while (i < endIndexExclusive && i < profile.Steps.Count)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    var step = profile.Steps[i];
                    int nextIndex = i + 1;

                    // Koşul/atlama adımları hedefi Sequence numarasıyla bulur ve döngü indeksini değiştirir
                    if (step.ActionType is MacroActionType.IfWindowTitle or MacroActionType.JumpToStep)
                    {
                        OnStepStarted?.Invoke(step.Sequence);
                        bool jump = step.ActionType == MacroActionType.JumpToStep ||
                                    !TitleMatches(_input.GetForegroundWindowTitle(), VariableResolver.Expand(step.Text));
                        if (jump)
                        {
                            int jumpIdx = FindStepIndexBySequence(profile, step.JumpToSequence);
                            if (jumpIdx >= 0) nextIndex = jumpIdx;
                        }

                        // Yalnızca atlamalardan oluşan bir döngü UI thread'ini kilitlemesin
                        await Task.Delay(1, cancellationToken);
                        i = nextIndex;
                        continue;
                    }

                    await ExecuteStepAsync(profile, step, cancellationToken);
                    i = nextIndex;
                }

                return true;
            }
            catch (OperationCanceledException)
            {
                OnCancelled?.Invoke();
            }
            catch (Exception ex)
            {
                OnError?.Invoke($"Hata: {ex.Message}");
            }

            return false;
        }

        internal static bool TitleMatches(string title, string? pattern) =>
            string.IsNullOrWhiteSpace(pattern) || title.Contains(pattern, StringComparison.OrdinalIgnoreCase);

        private static int FindStepIndexBySequence(MacroProfile profile, int sequence)
        {
            if (sequence <= 0) return -1;
            for (int j = 0; j < profile.Steps.Count; j++)
            {
                if (profile.Steps[j].Sequence == sequence) return j;
            }
            return -1;
        }

        private async Task ExecuteStepAsync(MacroProfile profile, MacroStep step, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (profile.IsSafetyLockEnabled)
            {
                ValidateSafetyLock(profile.TargetProcessName);
            }

            OnStepStarted?.Invoke(step.Sequence);

            if (step.ActionType == MacroActionType.TextDelay || step.DelayMs > 0)
            {
                await Task.Delay(Math.Max(0, step.DelayMs), cancellationToken);
            }

            cancellationToken.ThrowIfCancellationRequested();

            // Bekleme sırasında odak değişmiş olabilir: girdi göndermeden hemen önce yeniden doğrula
            if (profile.IsSafetyLockEnabled && step.ActionType != MacroActionType.TextDelay)
            {
                ValidateSafetyLock(profile.TargetProcessName);
            }

            switch (step.ActionType)
            {
                case MacroActionType.MouseClick:
                    _input.MoveCursor(step.MouseX, step.MouseY);
                    await Task.Delay(50, cancellationToken);
                    _input.LeftClick();
                    break;

                case MacroActionType.WriteText:
                    var text = VariableResolver.Expand(step.Text);
                    if (!string.IsNullOrEmpty(text))
                    {
                        _input.TypeText(text);
                    }
                    break;

                case MacroActionType.KeyPress:
                    var keyText = VariableResolver.Expand(step.Text);
                    if (!string.IsNullOrEmpty(keyText))
                    {
                        var code = ParseKeyCode(keyText);
                        if (code == VirtualKeyCode.NONAME)
                        {
                            throw new InvalidOperationException($"Adım {step.Sequence}: bilinmeyen tuş «{keyText}».");
                        }
                        _input.PressKey(code);
                    }
                    break;

                case MacroActionType.UiElementClick:
                    _input.ClickUiElement(step.UiElementName, step.UiAutomationId, step.UiClassName);
                    break;
            }
        }

        private void ValidateSafetyLock(string targetProcess)
        {
            var activeProcessName = _input.GetForegroundProcessName();
            if (activeProcessName == null)
            {
                throw new InvalidOperationException("Güvenli Mod Hatası: Odaklanmış herhangi bir pencere bulunamadı.");
            }

            // ponytail: "*" = odaklı pencere yeterli; süreç adı zorunlu değil
            if (targetProcess == MacroProfile.FocusOnlyTarget)
            {
                return;
            }

            if (activeProcessName.Length == 0)
            {
                throw new InvalidOperationException("Güvenli Mod Hatası: Aktif sürecin ismi çözümlenemedi.");
            }

            if (!activeProcessName.Equals(targetProcess, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    $"Güvenli Mod Koruması: Aktif uygulama '{activeProcessName}', hedeflenen '{targetProcess}' ile eşleşmiyor!");
            }
        }

        internal static VirtualKeyCode ParseKeyCode(string keyText)
        {
            keyText = keyText.ToUpperInvariant().Trim();
            switch (keyText)
            {
                case "ENTER":
                    return VirtualKeyCode.RETURN;
                case "BACKSPACE":
                    return VirtualKeyCode.BACK;
                case "ESC":
                    return VirtualKeyCode.ESCAPE;
                case "PAGEUP":
                    return VirtualKeyCode.PRIOR;
                case "PAGEDOWN":
                    return VirtualKeyCode.NEXT;
            }

            if (keyText.Length == 1 && keyText[0] is >= '0' and <= '9')
            {
                return (VirtualKeyCode)(0x30 + keyText[0] - '0');
            }

            if (keyText.Length == 0 || int.TryParse(keyText, out _))
            {
                return VirtualKeyCode.NONAME; // "13" gibi sayılar enum değeri (LBUTTON vb.) olarak yorumlanmasın
            }

            if (Enum.TryParse<VirtualKeyCode>(keyText, true, out var result))
            {
                return result;
            }

            if (Enum.TryParse<VirtualKeyCode>("VK_" + keyText, true, out result))
            {
                return result;
            }

            // Eski sürüm kayıtları WPF Key adlarını saklıyordu (ör. OEMPERIOD, D1): sanal tuş koduna çevir
            if (Enum.TryParse<Key>(keyText, true, out var wpfKey) && wpfKey != Key.None)
            {
                int vk = KeyInterop.VirtualKeyFromKey(wpfKey);
                if (vk != 0) return (VirtualKeyCode)vk;
            }

            return VirtualKeyCode.NONAME;
        }

        public void Dispose()
        {
            (_input as IDisposable)?.Dispose();
        }
    }
}
