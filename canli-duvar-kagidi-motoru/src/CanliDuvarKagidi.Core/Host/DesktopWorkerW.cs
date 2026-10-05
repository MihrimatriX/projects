using CanliDuvarKagidi.Core.Native;

namespace CanliDuvarKagidi.Core.Host;

public readonly struct DesktopAttachTarget
{
    public IntPtr Parent { get; init; }
    public IntPtr ShellView { get; init; }
    public IntPtr SystemWorkerW { get; init; }
    public bool RequiresLayeredHost { get; init; }
}

public static class DesktopWorkerW
{
    private static DesktopAttachTarget? _cached;

    public static IntPtr EnsureWorkerW() => EnsureAttachTarget().Parent;

    public static DesktopAttachTarget EnsureAttachTarget()
    {
        if (_cached is { } cached && NativeMethods.IsWindow(cached.Parent))
            return cached;

        _cached = ResolveAttachTarget();
        return _cached.Value;
    }

    public static void ResetCache() => _cached = null;

    // ponytail: debugger smoke — DesktopWorkerW.Diagnose() after Explorer restart
    public static string Diagnose()
    {
        try
        {
            ResetCache();
            var target = ResolveAttachTarget();
            return
                $"layered={target.RequiresLayeredHost} parent=0x{target.Parent:X} shell=0x{target.ShellView:X} worker=0x{target.SystemWorkerW:X}";
        }
        catch (Exception ex)
        {
            return $"error: {ex.Message}";
        }
    }

    // Masaustu gomme: Progman'a 0x052C mesaji gonderilince Explorer simge katmani (SHELLDLL_DefView)
    // ile arka plan arasina bir WorkerW penceresi olusturur. Host penceremizi bunun child'i yaparak
    // simgelerin ARKASINDA, duvar kagidinin ONUNDE ciziliriz. Windows surumune gore hedef farklidir.
    private static DesktopAttachTarget ResolveAttachTarget()
    {
        var progman = NativeMethods.FindWindow("Progman", null);
        if (progman == IntPtr.Zero)
            throw new InvalidOperationException("Progman penceresi bulunamadi.");

        RaiseDesktop(progman);

        var shellView = NativeMethods.FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null);
        var childWorkerW = NativeMethods.FindWindowEx(progman, IntPtr.Zero, "WorkerW", null);

        // Win11 24H2+ "raised desktop": layered child under DefView, above WorkerW
        if (HasRaisedDesktop(progman) && shellView != IntPtr.Zero)
        {
            return new DesktopAttachTarget
            {
                Parent = progman,
                ShellView = shellView,
                SystemWorkerW = childWorkerW,
                RequiresLayeredHost = true
            };
        }

        // Win11 26002+: WorkerW is a Progman child even before raised-desktop flag
        if (childWorkerW != IntPtr.Zero)
        {
            return new DesktopAttachTarget
            {
                Parent = childWorkerW,
                RequiresLayeredHost = false
            };
        }

        var legacyWorkerW = FindLegacyTopLevelWorkerW();
        if (legacyWorkerW == IntPtr.Zero)
            throw new InvalidOperationException("WorkerW penceresi bulunamadi.");

        return new DesktopAttachTarget
        {
            Parent = legacyWorkerW,
            RequiresLayeredHost = false
        };
    }

    private static void RaiseDesktop(IntPtr progman)
    {
        NativeMethods.SendMessageTimeout(
            progman, NativeMethods.WM_SPAWN_WORKER, new IntPtr(0xD), new IntPtr(0x1),
            0x0000, 1000, out _);
    }

    private static bool HasRaisedDesktop(IntPtr progman)
    {
        var style = NativeMethods.GetWindowLongPtr(progman, NativeMethods.GWL_EXSTYLE);
        return (style.ToInt64() & NativeMethods.WS_EX_NOREDIRECTIONBITMAP) != 0;
    }

    private static IntPtr FindLegacyTopLevelWorkerW()
    {
        IntPtr workerW = IntPtr.Zero;

        NativeMethods.EnumWindows((topLevel, _) =>
        {
            var shellView = NativeMethods.FindWindowEx(topLevel, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (shellView == IntPtr.Zero)
                return true;

            workerW = NativeMethods.FindWindowEx(IntPtr.Zero, topLevel, "WorkerW", null);
            return false;
        }, IntPtr.Zero);

        if (workerW != IntPtr.Zero)
            return workerW;

        NativeMethods.EnumWindows((topLevel, _) =>
        {
            if (NativeMethods.FindWindowEx(topLevel, IntPtr.Zero, "SHELLDLL_DefView", null) != IntPtr.Zero)
            {
                workerW = topLevel;
                return false;
            }

            return true;
        }, IntPtr.Zero);

        if (workerW != IntPtr.Zero)
            return workerW;

        NativeMethods.EnumWindows((topLevel, _) =>
        {
            if (NativeMethods.FindWindowEx(topLevel, IntPtr.Zero, "WorkerW", null) != IntPtr.Zero
                && NativeMethods.FindWindowEx(topLevel, IntPtr.Zero, "SHELLDLL_DefView", null) == IntPtr.Zero)
            {
                workerW = topLevel;
                return false;
            }

            return true;
        }, IntPtr.Zero);

        return workerW;
    }
}
