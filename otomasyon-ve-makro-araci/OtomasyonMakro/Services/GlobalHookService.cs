using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using OtomasyonMakro.Helpers;
using OtomasyonMakro.Models;

namespace OtomasyonMakro.Services
{
    /// <summary>Win32 düşük seviye kancaları; olayları <see cref="MacroRecorder"/>'a iletir.</summary>
    public class GlobalHookService
    {
        private IntPtr _mouseHookId = IntPtr.Zero;
        private IntPtr _keyboardHookId = IntPtr.Zero;

        // Pin delegate instances to prevent garbage collection
        private Win32Api.HookProc? _mouseProc;
        private Win32Api.HookProc? _keyboardProc;

        private readonly Stopwatch _stopwatch = Stopwatch.StartNew();
        private readonly MacroRecorder _recorder;

        public GlobalHookService()
        {
            _recorder = new MacroRecorder(() => _stopwatch.ElapsedMilliseconds);
            _recorder.OnStepRecorded += step => OnStepRecorded?.Invoke(step);
        }

        public event Action<MacroStep>? OnStepRecorded;

        public bool IsRecording { get; private set; }

        public bool IsPaused
        {
            get => _recorder.IsPaused;
            set => _recorder.IsPaused = value;
        }

        public void StartRecording()
        {
            if (IsRecording) return;

            _recorder.Reset();
            _mouseProc = MouseHookCallback;
            _keyboardProc = KeyboardHookCallback;

            var handle = Win32Api.GetModuleHandle(null);
            _mouseHookId = Win32Api.SetWindowsHookEx(Win32Api.WH_MOUSE_LL, _mouseProc, handle, 0);
            _keyboardHookId = Win32Api.SetWindowsHookEx(Win32Api.WH_KEYBOARD_LL, _keyboardProc, handle, 0);

            IsRecording = true;
        }

        public void StopRecording()
        {
            if (!IsRecording) return;

            IsRecording = false;

            // Flush any remaining characters in the keyboard buffer
            _recorder.Flush();
            _recorder.IsPaused = false;

            if (_mouseHookId != IntPtr.Zero)
            {
                Win32Api.UnhookWindowsHookEx(_mouseHookId);
                _mouseHookId = IntPtr.Zero;
            }

            if (_keyboardHookId != IntPtr.Zero)
            {
                Win32Api.UnhookWindowsHookEx(_keyboardHookId);
                _keyboardHookId = IntPtr.Zero;
            }

            _mouseProc = null;
            _keyboardProc = null;
        }

        private static bool IsDown(int vk) => (Win32Api.GetAsyncKeyState(vk) & 0x8000) != 0;

        private IntPtr MouseHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            // LL hook, kuran thread'in (UI) mesaj döngüsünde çağrılır; CallNextHookEx her durumda çağrılmalı.
            if (nCode >= 0 && wParam == (IntPtr)Win32Api.WM_LBUTTONDOWN)
            {
                var hookStruct = Marshal.PtrToStructure<Win32Api.MSLLHOOKSTRUCT>(lParam);

                // Kendi pencerelerimize (kayıt çubuğu "Durdur", "Duraklat" vb.) yapılan tıklamaları kaydetme
                Win32Api.GetWindowThreadProcessId(Win32Api.WindowFromPoint(hookStruct.pt), out uint pid);
                if (pid != (uint)Environment.ProcessId)
                    _recorder.MouseDown(hookStruct.pt.X, hookStruct.pt.Y);
            }
            return Win32Api.CallNextHookEx(_mouseHookId, nCode, wParam, lParam);
        }

        private IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && (wParam == (IntPtr)Win32Api.WM_KEYDOWN || wParam == (IntPtr)Win32Api.WM_SYSKEYDOWN))
            {
                var hookStruct = Marshal.PtrToStructure<Win32Api.KBDLLHOOKSTRUCT>(lParam);
                // GetKeyState başka uygulamaya yazılırken güncellenmez; hook içinde GetAsyncKeyState kullanılır
                _recorder.KeyDown(
                    hookStruct.vkCode,
                    shift: IsDown(0x10),
                    capsLock: Console.CapsLock,
                    ctrlOrAlt: IsDown(0x11) || IsDown(0x12));
            }
            return Win32Api.CallNextHookEx(_keyboardHookId, nCode, wParam, lParam);
        }
    }
}
