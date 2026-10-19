from __future__ import annotations

import sys

if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes

    _MUTEX = "Global\\DosyaYenidenAdlandirici_SingleInstance"
    user32 = ctypes.windll.user32

    class SingleInstance:
        def __init__(self) -> None:
            self._handle = ctypes.windll.kernel32.CreateMutexW(None, False, _MUTEX)
            self.is_first = ctypes.windll.kernel32.GetLastError() != 183

        def release(self) -> None:
            if self._handle:
                ctypes.windll.kernel32.CloseHandle(self._handle)
                self._handle = None

    def raise_existing_window(title: str) -> bool:
        """Calisan pencereyi one getir; bulunursa True."""
        found: list[int] = []

        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def callback(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd):
                return True
            length = user32.GetWindowTextLengthW(hwnd)
            if length <= 0:
                return True
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, length + 1)
            text = buf.value
            if title in text or "Adland" in text:
                found.append(hwnd)
            return True

        user32.EnumWindows(callback, 0)
        if not found:
            return False
        hwnd = found[0]
        from ui.window_utils import bring_window_to_front

        return bring_window_to_front(hwnd)

else:

    class SingleInstance:
        is_first = True

        def release(self) -> None:
            pass

    def raise_existing_window(_title: str) -> bool:
        return False
