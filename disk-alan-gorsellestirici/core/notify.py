from __future__ import annotations

import ctypes
import sys


def show_windows_toast(title: str, message: str) -> None:
    if sys.platform != "win32":
        return
    try:
        ctypes.windll.user32.MessageBoxW(0, message, title, 0x40)
    except OSError:
        pass
