from __future__ import annotations

import sys

from utils.app_info import APP_NAME, APP_VERSION
from utils.handoff import build_handoff_payload


def print_version() -> None:
    print(f"{APP_NAME} {APP_VERSION}")


def wants_version(argv: list[str]) -> bool:
    return "--version" in argv or "-V" in argv


def wants_forward_handoff(argv: list[str]) -> bool:
    """Yalnızca çalışan örneğe IPC ilet; başarısızsa çık kodu 1 (UI açmaz)."""
    return "--forward-handoff" in argv


def wants_wake(argv: list[str]) -> bool:
    return "--wake" in argv


def try_ipc_forward(argv: list[str]) -> bool:
    """İkinci örnek: QLocalSocket ile çalışan örneğe ilet."""
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtWidgets import QApplication

    from utils.ipc import send_handoff_to_running, wake_running_instance

    app = QCoreApplication.instance() or QApplication(sys.argv)
    if wake_running_instance():
        payload = build_handoff_payload(argv)
        if payload.get("roots") or payload.get("auto_scan"):
            return send_handoff_to_running(payload)
        return True

    payload = build_handoff_payload(argv)
    if not payload.get("roots") and not payload.get("auto_scan"):
        return False
    return send_handoff_to_running(payload)
