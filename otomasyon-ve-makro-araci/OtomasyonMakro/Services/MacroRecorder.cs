using System;
using System.Text;
using InputSimulatorStandard.Native;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    /// <summary>
    /// Ham klavye/fare olaylarını makro adımlarına çevirir (metin tamponu, bekleme süreleri, özel tuşlar).
    /// Win32 kancasından bağımsızdır; testler sahte saat ve sentetik olaylarla doğrular.
    /// </summary>
    public class MacroRecorder
    {
        public const int MinDelayMs = 50;

        private readonly Func<long> _clockMs;
        private readonly StringBuilder _textBuffer = new();
        private long _lastEventMs;
        private bool _isPaused;

        public MacroRecorder(Func<long> clockMs)
        {
            _clockMs = clockMs;
            _lastEventMs = clockMs();
        }

        public event Action<MacroStep>? OnStepRecorded;

        public bool IsPaused
        {
            get => _isPaused;
            set
            {
                if (_isPaused == value) return;
                if (value) Flush();
                _isPaused = value;
                // Duraklatılan süre bir sonraki adıma bekleme olarak eklenmesin
                if (!value) _lastEventMs = _clockMs();
            }
        }

        public void Reset()
        {
            _textBuffer.Clear();
            _isPaused = false;
            _lastEventMs = _clockMs();
        }

        /// <param name="ctrlOrAlt">Ctrl/Alt basılıyken gelen tuşlar (kısayollar) kaydedilmez.</param>
        public void KeyDown(uint vkCode, bool shift, bool capsLock, bool ctrlOrAlt)
        {
            // ESC acil durdurma, Ctrl+Alt+M kayıt kısayolu: kayda girmez
            if (_isPaused || ctrlOrAlt || vkCode == EmergencyStopMonitor.VK_ESCAPE) return;

            char c = GetPrintableChar(vkCode, shift, capsLock);
            if (c != '\0')
            {
                if (_textBuffer.Length == 0) EmitDelay(); // bekleme, yazmaya başlamadan önceki süredir
                _textBuffer.Append(c);
                _lastEventMs = _clockMs();
                return;
            }

            Flush();
            if (IsModifier(vkCode)) return;

            EmitDelay();
            Emit(new MacroStep { ActionType = MacroActionType.KeyPress, Text = KeyName(vkCode) });
        }

        public void MouseDown(int x, int y)
        {
            if (_isPaused) return;
            Flush();
            EmitDelay();
            Emit(new MacroStep { ActionType = MacroActionType.MouseClick, MouseX = x, MouseY = y });
        }

        /// <summary>Tampondaki metni tek bir "Metin yaz" adımı olarak yayar.</summary>
        public void Flush()
        {
            if (_textBuffer.Length == 0) return;
            var text = _textBuffer.ToString();
            _textBuffer.Clear();
            Emit(new MacroStep { ActionType = MacroActionType.WriteText, Text = text });
        }

        private void EmitDelay()
        {
            long now = _clockMs();
            long elapsed = now - _lastEventMs;
            _lastEventMs = now;
            if (elapsed > MinDelayMs)
            {
                Emit(new MacroStep { ActionType = MacroActionType.TextDelay, DelayMs = (int)Math.Min(elapsed, int.MaxValue) });
            }
        }

        private void Emit(MacroStep step) => OnStepRecorded?.Invoke(step);

        /// <summary>Oynatmada <see cref="PlaybackService.ParseKeyCode"/> ile birebir geri çözülen ad.</summary>
        public static string KeyName(uint vkCode)
        {
            var code = (VirtualKeyCode)vkCode;
            return Enum.IsDefined(code) ? code.ToString() : "VK_" + vkCode;
        }

        private static bool IsModifier(uint vk) =>
            vk is 0x10 or 0x11 or 0x12 // SHIFT, CONTROL, MENU
                or 0xA0 or 0xA1 or 0xA2 or 0xA3 or 0xA4 or 0xA5 // L/R SHIFT, CONTROL, MENU
                or 0x5B or 0x5C // LWIN, RWIN
                or 0x14; // CAPS LOCK (büyük harf durumu zaten metne yansır)

        // ponytail: yalnızca A-Z, 0-9, numpad ve boşluk metne girer; noktalama fiziksel tuş olarak kaydedilir,
        // Shift+rakam ("!") Shift'siz oynar. Klavye düzenine duyarlı çeviri gerekirse ToUnicodeEx.
        internal static char GetPrintableChar(uint vkCode, bool shift, bool capsLock)
        {
            if (vkCode >= 0x41 && vkCode <= 0x5A) // A-Z
            {
                bool upper = shift ^ capsLock;
                return (char)(vkCode + (upper ? 0 : 32));
            }
            if (vkCode >= 0x30 && vkCode <= 0x39) // 0-9
            {
                return (char)('0' + (vkCode - 0x30));
            }
            if (vkCode >= 0x60 && vkCode <= 0x69) // NumPad 0-9
            {
                return (char)('0' + (vkCode - 0x60));
            }
            if (vkCode == 0x20) // Spacebar
            {
                return ' ';
            }
            return '\0';
        }
    }
}
