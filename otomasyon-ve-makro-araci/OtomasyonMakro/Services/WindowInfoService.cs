using System;
using System.Runtime.InteropServices;
using System.Text;
using OtomasyonMakro.Helpers;

namespace OtomasyonMakro.Services
{
    public static class WindowInfoService
    {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        public static string GetForegroundWindowTitle()
        {
            IntPtr hwnd = Win32Api.GetForegroundWindow();
            if (hwnd == IntPtr.Zero)
            {
                return string.Empty;
            }

            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static bool TitleContains(string? pattern)
        {
            if (string.IsNullOrWhiteSpace(pattern))
            {
                return true;
            }

            var title = GetForegroundWindowTitle();
            return title.Contains(pattern, StringComparison.OrdinalIgnoreCase);
        }
    }
}
