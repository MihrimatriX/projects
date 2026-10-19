from __future__ import annotations

import sys

if sys.platform == "win32":
    import ctypes

    mutex_name = "Global\\DiskAlanGorsellestirici_SingleInstance"

    class SingleInstance:
        def __init__(self) -> None:
            self._handle = ctypes.windll.kernel32.CreateMutexW(None, False, mutex_name)
            self.is_first = ctypes.windll.kernel32.GetLastError() != 183

        def release(self) -> None:
            if self._handle:
                ctypes.windll.kernel32.CloseHandle(self._handle)
                self._handle = None
else:

    class SingleInstance:
        is_first = True

        def release(self) -> None:
            pass
