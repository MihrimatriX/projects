using System;
using System.Runtime.InteropServices;
using System.Threading;
using OtomasyonMakro.Helpers;

namespace OtomasyonMakro.Services
{
    /// <summary>
    /// Oynatma sürerken fiziksel ESC tuşunu global olarak dinler ve durdurma geri çağrısını tetikler.
    /// Kanca kendi mesaj döngüsü olan ayrı bir thread'de çalışır: UI thread'i uzun bir metin yazarken
    /// ya da bekleme adımındayken de ESC anında algılanır. Makronun kendisinin gönderdiği (enjekte) ESC yok sayılır.
    /// </summary>
    public sealed class EmergencyStopMonitor : IDisposable
    {
        public const uint VK_ESCAPE = 0x1B;
        private const uint LLKHF_INJECTED = 0x10;
        private const uint WM_QUIT = 0x0012;

        [StructLayout(LayoutKind.Sequential)]
        private struct MSG
        {
            public IntPtr hwnd;
            public uint message;
            public IntPtr wParam;
            public IntPtr lParam;
            public uint time;
            public Win32Api.POINT pt;
        }

        [DllImport("user32.dll")]
        private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

        [DllImport("user32.dll")]
        private static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

        [DllImport("user32.dll")]
        private static extern bool PostThreadMessage(uint idThread, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll")]
        private static extern uint GetCurrentThreadId();

        private readonly Action _onStop;
        private readonly Thread _thread;
        private Win32Api.HookProc? _proc; // GC'ye karşı sabitlenmiş delege
        private uint _threadId;
        private int _fired;

        /// <summary>Kanca kurulamadıysa false (yine de pencere odaktayken ESC çalışır).</summary>
        public bool IsActive { get; private set; }

        public static bool IsEmergencyKey(uint vkCode, uint flags) =>
            vkCode == VK_ESCAPE && (flags & LLKHF_INJECTED) == 0;

        private EmergencyStopMonitor(Action onStop)
        {
            _onStop = onStop;
            var ready = new ManualResetEventSlim(); // dispose edilmez: Wait zaman aşımında thread hâlâ Set çağırabilir
            _thread = new Thread(() => Run(ready)) { IsBackground = true, Name = "AcilDurdurma" };
            _thread.Start();
            ready.Wait(2000);
        }

        public static EmergencyStopMonitor Start(Action onStop) => new(onStop);

        private void Run(ManualResetEventSlim ready)
        {
            _threadId = GetCurrentThreadId();
            _proc = HookCallback;
            IntPtr hook = Win32Api.SetWindowsHookEx(Win32Api.WH_KEYBOARD_LL, _proc, Win32Api.GetModuleHandle(null), 0);
            IsActive = hook != IntPtr.Zero;
            PeekMessage(out _, IntPtr.Zero, 0, 0, 0); // mesaj kuyruğunu oluştur: Dispose'daki WM_QUIT kaybolmasın
            ready.Set();
            if (!IsActive) return;

            while (GetMessage(out _, IntPtr.Zero, 0, 0) > 0) { }
            Win32Api.UnhookWindowsHookEx(hook);
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && (wParam == (IntPtr)Win32Api.WM_KEYDOWN || wParam == (IntPtr)Win32Api.WM_SYSKEYDOWN))
            {
                var info = Marshal.PtrToStructure<Win32Api.KBDLLHOOKSTRUCT>(lParam);
                if (IsEmergencyKey(info.vkCode, info.flags) && Interlocked.Exchange(ref _fired, 1) == 0)
                {
                    // Kanca hızlı dönmeli; durdurma işi thread havuzunda
                    ThreadPool.QueueUserWorkItem(_ => _onStop());
                }
            }
            return Win32Api.CallNextHookEx(IntPtr.Zero, nCode, wParam, lParam);
        }

        public void Dispose()
        {
            if (_threadId != 0) PostThreadMessage(_threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);
            _thread.Join(1000);
        }
    }
}
