using System.Runtime.InteropServices;

namespace EkranZamani_WinUI.Services;

/// <summary>Win32 RegisterHotKey — gizli mesaj penceresi (WinForms bağımlılığı yok).</summary>
public sealed class WinUiHotkeyService : IDisposable
{
    private const string WindowClassName = "EkranZamaniHotkeyHost";
    private const int HotkeyId = 0x5A4D;
    private const uint ModCtrlShift = 0x0002 | 0x0004;
    private const uint VkE = 0x45;
    private const int WmHotkey = 0x0312;

    private static readonly WndProcDelegate StaticWndProc = WndProc;
    private IntPtr _hwnd;
    private Action? _callback;
    private bool _classRegistered;

    public void Register(Action showMainWindow)
    {
        _callback = showMainWindow;
        EnsureWindow();
        UnregisterHotKey(_hwnd, HotkeyId);
        RegisterHotKey(_hwnd, HotkeyId, ModCtrlShift, VkE);
    }

    public void Unregister()
    {
        if (_hwnd != IntPtr.Zero)
            UnregisterHotKey(_hwnd, HotkeyId);
    }

    private void EnsureWindow()
    {
        if (_hwnd != IntPtr.Zero) return;

        if (!_classRegistered)
        {
            var wc = new WndClassEx
            {
                cbSize = (uint)Marshal.SizeOf<WndClassEx>(),
                lpfnWndProc = Marshal.GetFunctionPointerForDelegate(StaticWndProc),
                hInstance = GetModuleHandle(null),
                lpszClassName = WindowClassName
            };
            RegisterClassEx(ref wc);
            _classRegistered = true;
        }

        _hwnd = CreateWindowEx(
            0,
            WindowClassName,
            WindowClassName,
            0,
            0, 0, 0, 0,
            HWND_MESSAGE,
            IntPtr.Zero,
            GetModuleHandle(null),
            IntPtr.Zero);
    }

    private static IntPtr WndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WmHotkey && Instance?._callback != null)
            Instance._callback();
        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    private static WinUiHotkeyService? Instance { get; set; }

    public WinUiHotkeyService() => Instance = this;

    public void Dispose()
    {
        Unregister();
        if (_hwnd != IntPtr.Zero)
        {
            DestroyWindow(_hwnd);
            _hwnd = IntPtr.Zero;
        }
        if (Instance == this)
            Instance = null;
    }

    private static readonly IntPtr HWND_MESSAGE = new(-3);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern ushort RegisterClassEx(ref WndClassEx lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateWindowEx(
        int dwExStyle, string lpClassName, string lpWindowName, int dwStyle,
        int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu,
        IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr DefWindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? lpModuleName);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate IntPtr WndProcDelegate(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WndClassEx
    {
        public uint cbSize;
        public uint style;
        public IntPtr lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string? lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }
}
