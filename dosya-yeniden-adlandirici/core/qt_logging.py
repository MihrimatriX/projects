from __future__ import annotations

import sys

from PySide6.QtCore import QtMsgType, qInstallMessageHandler


def install_qt_message_filter() -> None:
    """Bilinen zararsiz Qt platform uyarilarini filtrele."""

    def handler(mode: QtMsgType, _context, message: str) -> None:
        if "propagateSizeHints" in message or "does not support raise()" in message:
            return
        if mode == QtMsgType.QtWarningMsg:
            print(message, file=sys.stderr)
        elif mode == QtMsgType.QtCriticalMsg:
            print(message, file=sys.stderr)
        elif mode == QtMsgType.QtFatalMsg:
            print(message, file=sys.stderr)

    qInstallMessageHandler(handler)
