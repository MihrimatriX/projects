from __future__ import annotations

import sys

from utils.settings import APP_DIR

if sys.platform == "win32":
    import ctypes

    from utils.app_info import APP_ID

    _MUTEX = f"Global\\{APP_ID}_SingleInstance"

    class SingleInstance:
        def __init__(self) -> None:
            # InitialOwner=True: eşzamanlı ikinci süreç yarışını önler
            # use_last_error: ctypes.windll üzerinden GetLastError güvenilir değil (araya başka çağrı girebilir)
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            self._handle = kernel32.CreateMutexW(None, True, _MUTEX)
            self.is_first = ctypes.get_last_error() != 183  # ERROR_ALREADY_EXISTS

        def release(self) -> None:
            if self._handle:
                ctypes.windll.kernel32.CloseHandle(self._handle)
                self._handle = None

else:
    from PySide6.QtCore import QLockFile

    class SingleInstance:
        """macOS / Linux: QLockFile ile tek örnek."""

        def __init__(self) -> None:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            self._lock = QLockFile(str(APP_DIR / "instance.lock"))
            self._lock.setStaleLockTime(0)
            self.is_first = self._lock.tryLock(200)

        def release(self) -> None:
            if self.is_first:
                self._lock.unlock()
