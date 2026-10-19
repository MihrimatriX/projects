import os
import sys
import time
from pathlib import Path

from PySide6.QtGui import QIcon
from PySide6.QtWidgets import (
    QApplication,
    QMessageBox,
    QMenu,
    QStyle,
    QSystemTrayIcon,
)

from ui.main_window import MainWindow
from utils.app_info import APP_NAME, APP_VERSION
from utils.cli_args import (
    print_version,
    try_ipc_forward,
    wants_forward_handoff,
    wants_version,
    wants_wake,
)
from utils.handoff import clear_handoff, parse_cli_roots, read_handoff, should_auto_scan
from utils.ipc import HandoffServer
from utils.log_service import log
from utils.process_guard import kill_stale_instances
from utils.settings import SettingsStore
from utils.single_instance import SingleInstance

_ROOT = Path(__file__).resolve().parent


def _load_icon() -> QIcon:
    for name in ("icon.png", "icon.svg"):
        path = _ROOT / "assets" / name
        if path.exists():
            return QIcon(str(path))
    return QIcon()


def _acquire_single_instance(argv: list[str]) -> SingleInstance:
    """Tek örnek kilidi; takılı süreç varsa temizleyip bir kez daha dene."""
    instance = SingleInstance()
    if instance.is_first:
        return instance
    if try_ipc_forward(argv):
        log("Çalışan örneğe iletildi")
        sys.exit(0)
    kill_stale_instances()
    time.sleep(0.4)
    retry = SingleInstance()
    if retry.is_first:
        return retry
    app = QApplication.instance() or QApplication(sys.argv)
    QMessageBox.critical(
        None,
        APP_NAME,
        "Uygulama hâlâ arka planda takılı.\n"
        "Görev Yöneticisi → TekrarlananDosyaBulucu / python → Sonlandır,\n"
        "ardından tekrar deneyin.",
    )
    sys.exit(1)


def main() -> None:
    argv = sys.argv[1:]
    if wants_version(argv):
        print_version()
        sys.exit(0)

    if wants_forward_handoff(argv):
        from PySide6.QtCore import QCoreApplication

        QCoreApplication(sys.argv)
        sys.exit(0 if try_ipc_forward(argv) else 1)

    if wants_wake(argv):
        from utils.ipc import wake_running_instance

        app = QApplication(sys.argv)
        sys.exit(0 if wake_running_instance() else 1)

    if sys.platform != "win32" and QApplication.instance() is None:
        # QCoreApplication değil QApplication: aşağıda widget'lar için aynı örnek kullanılır
        QApplication(sys.argv)

    instance = _acquire_single_instance(argv)

    store = SettingsStore.instance()
    # try_ipc_forward zaten bir QApplication oluşturmuş olabilir; ikincisi RuntimeError verir
    app = QApplication.instance() or QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(not store.settings.minimize_to_tray)
    icon = _load_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)

    roots = parse_cli_roots(argv)
    auto_scan = should_auto_scan(argv)
    if "--handoff" in argv:
        data = read_handoff()
        if data:
            auto_scan = bool(data.get("auto_scan", True))
        clear_handoff()

    window = MainWindow(initial_roots=roots or None, auto_scan=auto_scan)
    if not icon.isNull():
        window.setWindowIcon(icon)

    ipc = HandoffServer()
    if ipc.start():
        ipc.received.connect(window.apply_external_handoff)
    else:
        log("IPC sunucusu başlatılamadı")

    tray = QSystemTrayIcon(window)
    tray.setToolTip(APP_NAME)
    tray.setIcon(icon if not icon.isNull() else app.style().standardIcon(QStyle.StandardPixmap.SP_DriveHDIcon))
    tray.show()
    menu = QMenu()
    menu.addAction("Göster", window.showNormal)
    menu.addAction("Tara (F5)", window._run_scan_for_mode)
    menu.addAction("Çıkış", app.quit)
    tray.setContextMenu(menu)
    tray.activated.connect(
        lambda r: window.showNormal()
        if r == QSystemTrayIcon.ActivationReason.Trigger
        else None
    )
    window.set_tray(tray)

    window._bring_to_front()
    log(f"Başlatıldı {APP_VERSION} — {len(window._roots())} kök")
    code = app.exec()
    # Tepsiden "Çıkış" closeEvent'i atlar; çalışan tarama thread'i yok edilmeden önce durdurulmalı
    if window._worker and window._worker.isRunning():
        window._worker.cancel()
        window._worker.wait()
    ipc.stop()
    instance.release()
    sys.exit(code)


if __name__ == "__main__":
    main()
