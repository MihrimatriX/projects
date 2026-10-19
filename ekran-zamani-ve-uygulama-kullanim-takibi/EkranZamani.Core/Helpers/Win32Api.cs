using System;
using System.Runtime.InteropServices;
using System.Text;

namespace EkranZamani.Helpers
{
    public static class Win32Api
    {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO
        {
            public uint cbSize;
            public uint dwTime;
        }

        public static string GetActiveWindowTitle(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero) return string.Empty;
            var builder = new StringBuilder(256);
            if (GetWindowText(hwnd, builder, 256) > 0)
            {
                return builder.ToString();
            }
            return string.Empty;
        }

        public static string GetProcessNameByHwnd(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero) return "Unknown";
            
            GetWindowThreadProcessId(hwnd, out uint pid);
            if (pid == 0) return "Unknown";

            try
            {
                using (var proc = System.Diagnostics.Process.GetProcessById((int)pid))
                {
                    return proc.ProcessName;
                }
            }
            catch
            {
                return "Unknown";
            }
        }

        // Returns idle time in seconds
        public static double GetIdleTime()
        {
            var lii = new LASTINPUTINFO();
            lii.cbSize = (uint)Marshal.SizeOf(lii);
            if (GetLastInputInfo(ref lii))
            {
                uint elapsedTicks = (uint)Environment.TickCount - lii.dwTime;
                return elapsedTicks / 1000.0;
            }
            return 0;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

        [DllImport("user32.dll")]
        private static extern bool CloseDesktop(IntPtr hDesktop);

        private const uint DESKTOP_SWITCHDESKTOP = 0x0100;

        // Kilit ekranı / UAC güvenli masaüstü etkinken giriş masaüstü kullanıcı oturumundan açılamaz.
        public static bool IsWorkstationLocked()
        {
            IntPtr desk = OpenInputDesktop(0, false, DESKTOP_SWITCHDESKTOP);
            if (desk == IntPtr.Zero) return true;
            CloseDesktop(desk);
            return false;
        }
    }
}
