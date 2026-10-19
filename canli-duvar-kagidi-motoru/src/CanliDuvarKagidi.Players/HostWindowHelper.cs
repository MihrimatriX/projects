using CanliDuvarKagidi.Core.Native;

namespace CanliDuvarKagidi.Players;

internal static class HostWindowHelper
{
    public static Form CreateChildForm(IntPtr hostWindow, int width, int height)
    {
        var form = new Form
        {
            FormBorderStyle = FormBorderStyle.None,
            ShowInTaskbar = false,
            StartPosition = FormStartPosition.Manual,
            TopLevel = false,
            BackColor = Color.Black,
            Width = width,
            Height = height
        };

        var handle = form.Handle;
        NativeMethods.SetParent(handle, hostWindow);
        NativeMethods.SetWindowPos(
            handle, IntPtr.Zero, 0, 0, width, height,
            NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_SHOWWINDOW);
        form.Show();
        return form;
    }
}
