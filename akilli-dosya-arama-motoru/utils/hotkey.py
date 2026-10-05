"""Windows global kısayol (Ctrl+Space) — Spotlight benzeri."""

from __future__ import annotations

import sys
from typing import Callable

if sys.platform != "win32":
    HotkeyPoller = None  # type: ignore[misc, assignment]
else:
    import ctypes
    from ctypes import wintypes

    from PySide6.QtCore import QAbstractNativeEventFilter, QCoreApplication, QObject, QTimer

    WM_HOTKEY = 0x0312
    MOD_CONTROL = 0x0002
    HOTKEY_ID = 0xAD21
    VK_SPACE = 0x20

    user32 = ctypes.windll.user32

    class _HotkeyFilter(QAbstractNativeEventFilter):
        """WM_HOTKEY, Qt olay döngüsünün kendi PeekMessage'ı tarafından tüketilir;
        bu yüzden mesajı zamanlayıcıyla değil, native event filter ile yakalarız."""

        def __init__(self, on_hotkey: Callable[[], None]) -> None:
            super().__init__()
            self._on_hotkey = on_hotkey

        def nativeEventFilter(self, event_type, message):
            msg = wintypes.MSG.from_address(int(message))
            if msg.message == WM_HOTKEY and msg.wParam == HOTKEY_ID:
                # Filtre içinden pencere açmak yerine olay döngüsüne bırak.
                QTimer.singleShot(0, self._on_hotkey)
                return True, 0
            return False, 0

    class HotkeyPoller(QObject):
        """RegisterHotKey(NULL) → iş parçacığı mesajı; native event filter ile dinlenir."""

        def __init__(self, on_hotkey: Callable[[], None], parent: QObject | None = None) -> None:
            super().__init__(parent)
            self._registered = False
            self._filter = _HotkeyFilter(on_hotkey)

        def register(self) -> bool:
            self._registered = bool(
                user32.RegisterHotKey(None, HOTKEY_ID, MOD_CONTROL, VK_SPACE)
            )
            if self._registered:
                QCoreApplication.instance().installNativeEventFilter(self._filter)
            return self._registered

        def unregister(self) -> None:
            if self._registered:
                QCoreApplication.instance().removeNativeEventFilter(self._filter)
                user32.UnregisterHotKey(None, HOTKEY_ID)
                self._registered = False
