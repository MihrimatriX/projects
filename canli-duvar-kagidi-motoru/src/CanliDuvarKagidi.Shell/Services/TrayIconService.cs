using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;

namespace CanliDuvarKagidi_Shell.Services;

public sealed class TrayIconService : IDisposable
{
    private const uint WM_USER = 0x0400;
    private const uint WM_TRAYICON = WM_USER + 1;
    private const uint NIM_ADD = 0x00000000;
    private const uint NIM_DELETE = 0x00000002;
    private const uint NIF_MESSAGE = 0x00000001;
    private const uint NIF_ICON = 0x00000002;
    private const uint NIF_TIP = 0x00000004;
    private const uint WM_LBUTTONDBLCLK = 0x0203;
    private const uint WM_RBUTTONUP = 0x0205;
    private const uint MF_STRING = 0x00000000;
    private const uint MF_SEPARATOR = 0x00000800;
    private const uint MF_CHECKED = 0x00000008;
    private const uint TPM_RETURNCMD = 0x0100;
    private const int ID_SHOW = 1001;
    private const int ID_EXIT = 1002;
    private const int ID_PAUSE = 1003;
    private const uint IMAGE_ICON = 1;
    private const uint LR_LOADFROMFILE = 0x10;
    private const uint LR_DEFAULTSIZE = 0x40;

    private readonly Window _window;
    private readonly NativeWindow _nativeWindow;
    private readonly IntPtr _icon;
    private bool _disposed;

    public TrayIconService(Window window)
    {
        _window = window;
        _nativeWindow = new NativeWindow(this);
        // Uygulama simgesi; dosya yoksa Windows varsayilani
        var ico = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
        _icon = File.Exists(ico) ? LoadImage(IntPtr.Zero, ico, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE) : IntPtr.Zero;
        if (_icon == IntPtr.Zero)
            _icon = LoadIcon(IntPtr.Zero, new IntPtr(32512)); // IDI_APPLICATION
        AddTrayIcon();
    }

    public void ShowWindow()
    {
        _window.AppWindow.Show();
        _window.Activate();
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        var data = CreateNotifyData();
        Shell_NotifyIcon(NIM_DELETE, ref data);
        _nativeWindow.Dispose();
        _disposed = true;
    }

    private void AddTrayIcon()
    {
        var data = CreateNotifyData();
        Shell_NotifyIcon(NIM_ADD, ref data);
    }

    private NOTIFYICONDATA CreateNotifyData()
    {
        return new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _nativeWindow.Handle,
            uID = 1,
            uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP,
            uCallbackMessage = WM_TRAYICON,
            hIcon = _icon,
            szTip = "Canlı Duvar Kağıdı"
        };
    }

    private void ShowContextMenu()
    {
        var menu = CreatePopupMenu();
        AppendMenu(menu, MF_STRING, ID_SHOW, "Göster");
        AppendMenu(menu, MF_STRING | (AppServices.Engine.IsUserPaused ? MF_CHECKED : 0), ID_PAUSE, "Duraklat");
        AppendMenu(menu, MF_SEPARATOR, 0, string.Empty);
        AppendMenu(menu, MF_STRING, ID_EXIT, "Çıkış");
        GetCursorPos(out var point);
        SetForegroundWindow(_nativeWindow.Handle);
        var cmd = TrackPopupMenuEx(menu, TPM_RETURNCMD, point.X, point.Y, _nativeWindow.Handle, IntPtr.Zero);
        DestroyMenu(menu);

        if (cmd == ID_SHOW)
            ShowWindow();
        else if (cmd == ID_PAUSE)
            AppServices.Engine.IsUserPaused = !AppServices.Engine.IsUserPaused;
        else if (cmd == ID_EXIT)
            Application.Current.Exit();
    }

    private void HandleTrayEvent(uint mouseMessage)
    {
        if (mouseMessage == WM_LBUTTONDBLCLK)
            ShowWindow();
        else if (mouseMessage == WM_RBUTTONUP)
            ShowContextMenu();
    }

    private sealed class NativeWindow : IDisposable
    {
        private readonly TrayIconService _owner;
        private readonly IntPtr _handle;
        private readonly NativeMethods.WndProc _proc;
        private bool _disposed;

        public NativeWindow(TrayIconService owner)
        {
            _owner = owner;
            _proc = WindowProc;
            var wc = new NativeMethods.WNDCLASSEX
            {
                cbSize = (uint)Marshal.SizeOf<NativeMethods.WNDCLASSEX>(),
                lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_proc),
                hInstance = NativeMethods.GetModuleHandle(null),
                lpszClassName = "CanliDuvarKagidiTrayWindow"
            };
            NativeMethods.RegisterClassEx(ref wc);
            _handle = NativeMethods.CreateWindowEx(
                0, wc.lpszClassName, "TrayHost", 0,
                0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, wc.hInstance, IntPtr.Zero);
        }

        public IntPtr Handle => _handle;

        private IntPtr WindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
        {
            if (msg == WM_TRAYICON)
                _owner.HandleTrayEvent((uint)lParam);

            return NativeMethods.DefWindowProc(hWnd, msg, wParam, lParam);
        }

        public void Dispose()
        {
            if (_disposed)
                return;
            if (_handle != IntPtr.Zero)
                NativeMethods.DestroyWindow(_handle);
            _disposed = true;
        }
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
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadImage(IntPtr hInst, string name, uint type, int cx, int cy, uint fuLoad);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("user32.dll")]
    private static extern IntPtr CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, int uIDNewItem, string lpNewItem);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern int TrackPopupMenuEx(IntPtr hmenu, uint fuFlags, int x, int y, IntPtr hwnd, IntPtr lptpm);

    [DllImport("user32.dll")]
    private static extern bool DestroyMenu(IntPtr hMenu);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }
}
