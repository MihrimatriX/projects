import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtGui import QAction, QIcon, QKeySequence
from PySide6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon

from core.app_info import APP_NAME
from core.single_instance import SingleInstance
from core.settings import SettingsStore
from ui.dialogs.welcome_dialog import WelcomeDialog
from ui.main_window import MainWindow


def _app_icon() -> QIcon | None:
    root = Path(__file__).resolve().parent
    for name in ("icon.ico", "icon.png"):
        path = root / "assets" / name
        if path.is_file():
            return QIcon(str(path))
    return None


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    icon = _app_icon()
    if icon:
        app.setWindowIcon(icon)

    instance = SingleInstance()
    if not instance.is_first:
        QMessageBox.information(None, APP_NAME, "Uygulama zaten çalışıyor.")
        sys.exit(0)

    settings = SettingsStore.instance()
    window = MainWindow()
    window.resize(settings.settings.window_width, settings.settings.window_height)

    pick_folder = False
    if not settings.settings.first_run_completed:
        welcome = WelcomeDialog(window)
        if welcome.exec():
            settings.settings.first_run_completed = True
            settings.save()
            pick_folder = welcome.pick_folder

    window.show()
    if pick_folder:
        QTimer.singleShot(0, window.pick_folder)

    tray = QSystemTrayIcon(window)
    tray.setToolTip(APP_NAME)
    if icon:
        tray.setIcon(icon)
    tray.show()

    menu = QMenu()
    show_action = QAction("Göster", window)
    show_action.triggered.connect(window.showNormal)
    scan_action = QAction("Tara", window)
    scan_action.triggered.connect(window.start_scan_from_shortcut)
    quit_action = QAction("Çık", window)
    quit_action.triggered.connect(app.quit)
    menu.addAction(show_action)
    menu.addAction(scan_action)
    menu.addSeparator()
    menu.addAction(quit_action)
    tray.setContextMenu(menu)
    tray.activated.connect(lambda r: window.showNormal() if r == QSystemTrayIcon.ActivationReason.Trigger else None)

    window.set_tray(tray)

    def on_quit() -> None:
        settings.settings.window_width = window.width()
        settings.settings.window_height = window.height()
        settings.save()
        instance.release()

    app.aboutToQuit.connect(on_quit)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
