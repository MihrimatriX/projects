using System.Runtime.InteropServices;
using CanliDuvarKagidi.Core.Abstractions;
using CanliDuvarKagidi.Core.Models;
using CanliDuvarKagidi.Core.Native;

namespace CanliDuvarKagidi.Core.Host;

public sealed class DesktopWallpaperHost : IWallpaperHost
{
    private const string WindowClassName = "CanliDuvarKagidiHostWindow";
    private const uint ErrorClassAlreadyExists = 1410;
    private static readonly object ClassLock = new();
    private static bool _classRegistered;
    private static NativeMethods.WndProc? _wndProcDelegate;

    private readonly MonitorInfo _monitor;
    private DesktopAttachTarget _attachTarget;
    private IntPtr _handle;
    private bool _disposed;

    public DesktopWallpaperHost(MonitorInfo monitor)
    {
        _monitor = monitor;
        EnsureWindowClassRegistered();
    }

    public IntPtr WindowHandle => _handle;
    public MonitorInfo Monitor => _monitor;
    public bool IsAttached { get; private set; }

    public Task AttachToDesktopAsync()
    {
        DesktopWorkerW.ResetCache();
        _attachTarget = DesktopWorkerW.EnsureAttachTarget();

        CreateHostWindow(_attachTarget);
        ApplyPlacement(_monitor);
        NativeMethods.ShowWindow(_handle, 5);
        IsAttached = true;
        return Task.CompletedTask;
    }

    public void Show() => NativeMethods.ShowWindow(_handle, 5);

    public void Hide() => NativeMethods.ShowWindow(_handle, 0);

    public void SetBounds(MonitorInfo monitor) => ApplyPlacement(monitor);

    public void Dispose()
    {
        if (_disposed)
            return;

        if (_handle != IntPtr.Zero)
        {
            NativeMethods.DestroyWindow(_handle);
            _handle = IntPtr.Zero;
        }

        _disposed = true;
    }

    private void ApplyPlacement(MonitorInfo monitor)
    {
        var (x, y) = HostOrigin(monitor);

        if (_attachTarget.RequiresLayeredHost && _attachTarget.ShellView != IntPtr.Zero)
        {
            NativeMethods.SetWindowPos(
                _handle, _attachTarget.ShellView,
                x, y, monitor.Width, monitor.Height,
                NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_SHOWWINDOW);

            if (_attachTarget.SystemWorkerW != IntPtr.Zero)
            {
                NativeMethods.SetWindowPos(
                    _attachTarget.SystemWorkerW, _handle,
                    0, 0, 0, 0,
                    NativeMethods.SWP_NOMOVE | NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
            }

            return;
        }

        NativeMethods.SetWindowPos(
            _handle, IntPtr.Zero,
            x, y, monitor.Width, monitor.Height,
            NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_SHOWWINDOW);
    }

    private (int X, int Y) HostOrigin(MonitorInfo monitor)
    {
        if (_attachTarget.Parent == IntPtr.Zero)
            return (monitor.X, monitor.Y);

        if (!NativeMethods.GetWindowRect(_attachTarget.Parent, out var rect))
            return (monitor.X, monitor.Y);

        return (monitor.X - rect.Left, monitor.Y - rect.Top);
    }

    private void CreateHostWindow(DesktopAttachTarget attach)
    {
        var hInstance = NativeMethods.GetModuleHandle(null);
        var (x, y) = HostOrigin(_monitor);

        if (attach.RequiresLayeredHost)
        {
            // ponytail: bazi Win11 build'lerinde WS_EX_LAYERED|WS_CHILD CreateWindowEx'i kirar — popup+SetParent
            _handle = NativeMethods.CreateWindowEx(
                NativeMethods.WS_EX_LAYERED | NativeMethods.WS_EX_NOACTIVATE,
                WindowClassName,
                "CanliDuvarKagidiHost",
                NativeMethods.WS_POPUP,
                _monitor.X, _monitor.Y, _monitor.Width, _monitor.Height,
                IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);

            if (_handle == IntPtr.Zero)
                throw CreateHostFailed();

            NativeMethods.SetParent(_handle, attach.Parent);

            var style = NativeMethods.GetWindowLongPtr(_handle, NativeMethods.GWL_STYLE);
            var childStyle = (style.ToInt64() | NativeMethods.WS_CHILD) & ~NativeMethods.WS_POPUP;
            NativeMethods.SetWindowLongPtr(_handle, NativeMethods.GWL_STYLE, new IntPtr(childStyle));

            NativeMethods.SetWindowPos(
                _handle, IntPtr.Zero,
                x, y, _monitor.Width, _monitor.Height,
                NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_FRAMECHANGED);

            NativeMethods.SetLayeredWindowAttributes(_handle, 0, 255, NativeMethods.LWA_ALPHA);
            return;
        }

        var exStyle = NativeMethods.WS_EX_TOOLWINDOW | NativeMethods.WS_EX_NOACTIVATE;
        _handle = NativeMethods.CreateWindowEx(
            exStyle,
            WindowClassName,
            "CanliDuvarKagidiHost",
            NativeMethods.WS_CHILD | NativeMethods.WS_VISIBLE,
            x, y, _monitor.Width, _monitor.Height,
            attach.Parent, IntPtr.Zero, hInstance, IntPtr.Zero);

        if (_handle == IntPtr.Zero)
            throw CreateHostFailed();
    }

    private static InvalidOperationException CreateHostFailed()
    {
        var error = NativeMethods.GetLastError();
        return new InvalidOperationException(
            $"Duvar kagidi host penceresi olusturulamadi. Win32 hata kodu: {error}");
    }

    private static void EnsureWindowClassRegistered()
    {
        lock (ClassLock)
        {
            if (_classRegistered)
                return;

            _wndProcDelegate = DefWindowProc;
            var hInstance = NativeMethods.GetModuleHandle(null);
            var wc = new NativeMethods.WNDCLASSEX
            {
                cbSize = (uint)Marshal.SizeOf<NativeMethods.WNDCLASSEX>(),
                lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_wndProcDelegate),
                hInstance = hInstance,
                lpszClassName = WindowClassName,
                hbrBackground = new IntPtr(6) // COLOR_WINDOW + 1
            };

            if (NativeMethods.RegisterClassEx(ref wc) == 0)
            {
                var error = NativeMethods.GetLastError();
                if (error != ErrorClassAlreadyExists)
                    throw new InvalidOperationException(
                        $"Host pencere sinifi kaydedilemedi. Win32 hata kodu: {error}");
            }

            _classRegistered = true;
        }
    }

    private static IntPtr DefWindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam) =>
        NativeMethods.DefWindowProc(hWnd, msg, wParam, lParam);
}
