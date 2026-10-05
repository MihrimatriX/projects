using System.Runtime.InteropServices;

namespace EkranZamani_WinUI.Services;

/// <summary>Win32 Shell_NotifyIcon — no WinForms / H.NotifyIcon (WinUI crash source).</summary>
public sealed class WinUiTrayService : IDisposable
{
    private const uint NimAdd = 0x00000000;
    private const uint NimModify = 0x00000001;
    private const uint NimDelete = 0x00000002;
    private const uint NimSetVersion = 0x00000004;
    private const uint NifMessage = 0x00000001;
    private const uint NifIcon = 0x00000002;
    private const uint NifTip = 0x00000004;
    private const uint NifShowTip = 0x00000080;
    private const uint WmTray = 0x8000;
    private const uint WmLButtonDblClk = 0x0203;
    private const uint WmRButtonUp = 0x0205;
    private const uint TpmReturnCmd = 0x0100;
    private const uint MfString = 0x00000000;
    private const uint MfSeparator = 0x00000800;

    private static readonly WndProcDelegate StaticWndProc = WndProc;
    private static WinUiTrayService? _active;

    private readonly uint _id = 1;
    private IntPtr _hwnd;
    private IntPtr _icon;
    private Action? _showMainWindow;
    private Action? _toggleTracking;
    private Action? _exit;
    private bool _added;

    public void Initialize(Action showMainWindow, Action toggleTracking, Action exit)
    {
        _showMainWindow = showMainWindow;
        _toggleTracking = toggleTracking;
        _exit = exit;
        _active = this;

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
        if (!File.Exists(iconPath)) return;

        _icon = LoadImage(IntPtr.Zero, iconPath, 1, 0, 0, 0x00000010 | 0x00008000);
        if (_icon == IntPtr.Zero) return;

        EnsureWindow();
        AddOrUpdate();
    }

    public void ShowBalloon(string title, string message)
    {
        if (!_added || _hwnd == IntPtr.Zero) return;
        try
        {
            var data = CreateData();
            data.uFlags = NifInfo | NifShowTip;
            data.uTimeoutOrVersion = 4000;
            data.InfoTitle = title;
            data.Info = message.Length > 255 ? message[..255] : message;
            Shell_NotifyIcon(NimModify, ref data);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Balloon: {ex.Message}");
        }
    }

    public void UpdateTooltip(string summary)
    {
        if (!_added) return;
        var data = CreateData();
        data.uFlags = NifTip;
        data.szTip = string.IsNullOrWhiteSpace(summary) ? "Ekran Zamanı"
            : summary.Length > 127 ? summary[..127] : summary;
        Shell_NotifyIcon(NimModify, ref data);
    }

    public void Dispose()
    {
        if (_added)
        {
            var data = CreateData();
            Shell_NotifyIcon(NimDelete, ref data);
            _added = false;
        }

        if (_icon != IntPtr.Zero)
        {
            DestroyIcon(_icon);
            _icon = IntPtr.Zero;
        }

        if (_hwnd != IntPtr.Zero)
        {
            DestroyWindow(_hwnd);
            _hwnd = IntPtr.Zero;
        }

        if (_active == this) _active = null;
    }

    private void EnsureWindow()
    {
        if (_hwnd != IntPtr.Zero) return;

        var wc = new WndClassEx
        {
            cbSize = (uint)Marshal.SizeOf<WndClassEx>(),
            lpfnWndProc = Marshal.GetFunctionPointerForDelegate(StaticWndProc),
            hInstance = GetModuleHandle(null),
            lpszClassName = "EkranZamaniTrayHost"
        };
        RegisterClassEx(ref wc);

        _hwnd = CreateWindowEx(
            0, wc.lpszClassName, wc.lpszClassName, 0,
            0, 0, 0, 0, HWND_MESSAGE, IntPtr.Zero, wc.hInstance, IntPtr.Zero);
    }

    private void AddOrUpdate()
    {
        var data = CreateData();
        data.uFlags = NifMessage | NifIcon | NifTip;
        data.uCallbackMessage = WmTray;
        data.hIcon = _icon;
        data.szTip = "Ekran Zamanı";
        _added = Shell_NotifyIcon(_added ? NimModify : NimAdd, ref data);
        if (_added)
        {
            // NOTIFYICONDATAW'da uTimeout/uVersion bir union'dır (ayrı alan cbSize'ı bozuyordu).
            // Sürüm 0 (eski davranış) bilerek korunur: sürüm 4 NIF_SHOWTIP olmadan ipucunu gizler.
            data.uTimeoutOrVersion = 0;
            Shell_NotifyIcon(NimSetVersion, ref data);
        }
    }

    private NOTIFYICONDATA CreateData() => new()
    {
        cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
        hWnd = _hwnd,
        uID = _id
    };

    private static IntPtr WndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WmTray && _active != null)
        {
            var ev = (uint)lParam & 0xFFFF;
            if (ev == WmLButtonDblClk)
                _active._showMainWindow?.Invoke();
            else if (ev == WmRButtonUp)
                _active.ShowContextMenu();
        }

        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    private void ShowContextMenu()
    {
        var menu = CreatePopupMenu();
        AppendMenu(menu, MfString, 1, "İzlemeyi duraklat");
        AppendMenu(menu, MfString, 2, "Dashboard'u aç");
        AppendMenu(menu, MfSeparator, 0, null);
        AppendMenu(menu, MfString, 3, "Çıkış");

        GetCursorPos(out var pt);
        SetForegroundWindow(_hwnd);
        var cmd = TrackPopupMenu(menu, TpmReturnCmd, pt.X, pt.Y, 0, _hwnd, IntPtr.Zero);
        DestroyMenu(menu);

        switch (cmd)
        {
            case 1: _toggleTracking?.Invoke(); break;
            case 2: _showMainWindow?.Invoke(); break;
            case 3: _exit?.Invoke(); break;
        }
    }

    private const uint NifInfo = 0x00000010;

    private static readonly IntPtr HWND_MESSAGE = new(-3);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern ushort RegisterClassEx(ref WndClassEx lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateWindowEx(
        int dwExStyle, string lpClassName, string lpWindowName, int dwStyle,
        int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu,
        IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll")]
    private static extern IntPtr DefWindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyWindow(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadImage(IntPtr hInst, string name, uint type, int cx, int cy, uint fuLoad);

    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr hIcon);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? lpModuleName);

    [DllImport("user32.dll")]
    private static extern IntPtr CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, uint uIdNewItem, string? lpNewItem);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern uint TrackPopupMenu(IntPtr hMenu, uint uFlags, int x, int y, int nReserved, IntPtr hWnd, IntPtr prcRect);

    [DllImport("user32.dll")]
    private static extern bool DestroyMenu(IntPtr hMenu);

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

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NOTIFYICONDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID;
        public uint uFlags;
        public uint uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
        public uint dwState;
        public uint dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string Info;
        public uint uTimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string InfoTitle;
        public uint dwInfoFlags;
        public Guid guidItem;
        public IntPtr hBalloonIcon;
    }
}
