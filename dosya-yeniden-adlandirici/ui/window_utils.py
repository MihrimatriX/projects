from __future__ import annotations

import sys

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QWidget


def focus_window(widget: QWidget) -> None:
    """Pencereyi öne getir — raise() bazı platformlarda desteklenmiyor."""
    if not widget.isVisible():
        widget.show()
    state = widget.windowState()
    # PySide6 6.11: WindowState bayrağı int() ile çevrilemiyor (TypeError açılışı çökertiyordu).
    if state & Qt.WindowState.WindowMinimized:
        widget.setWindowState(state & ~Qt.WindowState.WindowMinimized)
    widget.showNormal()
    widget.activateWindow()

    if sys.platform == "win32":
        hwnd = int(widget.winId())
        if hwnd:
            bring_window_to_front(hwnd)


def bring_window_to_front(hwnd: int) -> bool:
    """Windows: görev çubuğunda yanıp söndür ve öne al."""
    if sys.platform != "win32" or not hwnd:
        return False

    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32

    SW_RESTORE = 9
    SW_SHOW = 5

    if user32.IsIconic(hwnd):
        user32.ShowWindow(hwnd, SW_RESTORE)
    else:
        user32.ShowWindow(hwnd, SW_SHOW)

    class FLASHWINFO(ctypes.Structure):
        _fields_ = [
            ("cbSize", ctypes.c_uint),
            ("hwnd", wintypes.HWND),
            ("dwFlags", ctypes.c_uint),
            ("uCount", ctypes.c_uint),
            ("dwTimeout", ctypes.c_uint),
        ]

    FLASHW_ALL = 3
    flash = FLASHWINFO()
    flash.cbSize = ctypes.sizeof(FLASHWINFO)
    flash.hwnd = hwnd
    flash.dwFlags = FLASHW_ALL
    flash.uCount = 3
    user32.FlashWindowEx(ctypes.byref(flash))

    foreground = user32.GetForegroundWindow()
    fg_thread = user32.GetWindowThreadProcessId(foreground, None)
    cur_thread = kernel32.GetCurrentThreadId()
    attached = False
    if fg_thread and fg_thread != cur_thread:
        attached = bool(user32.AttachThreadInput(cur_thread, fg_thread, True))
    try:
        user32.SetForegroundWindow(hwnd)
        user32.BringWindowToTop(hwnd)
    finally:
        if attached:
            user32.AttachThreadInput(cur_thread, fg_thread, False)
    return True
