import atexit
import sys
from pathlib import Path

from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtWidgets import QApplication, QMessageBox

from core.app_info import APP_NAME
from core.qt_fonts import ensure_qt_font_directory
from core.qt_logging import install_qt_message_filter
from core.single_instance import SingleInstance, raise_existing_window
from ui.main_window import MainWindow
from ui.window_utils import focus_window


def _app_icon() -> QIcon | None:
    root = Path(__file__).resolve().parent
    for name in ("icon.ico", "icon.png"):
        path = root / "assets" / name
        if path.is_file():
            return QIcon(str(path))
    return None


def _center_on_screen(window) -> None:
    screen = QGuiApplication.primaryScreen()
    if not screen:
        return
    geo = screen.availableGeometry()
    window.move(
        geo.x() + max(0, (geo.width() - window.width()) // 2),
        geo.y() + max(0, (geo.height() - window.height()) // 2),
    )


def main() -> None:
    install_qt_message_filter()
    ensure_qt_font_directory()
    instance = SingleInstance()
    atexit.register(instance.release)

    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setFont(QFont("Segoe UI", 10))
    icon = _app_icon()
    if icon:
        app.setWindowIcon(icon)

    if not instance.is_first:
        if raise_existing_window(APP_NAME):
            QMessageBox.information(
                None,
                APP_NAME,
                "Uygulama zaten açık. Pencere görev çubuğunda yanıp söndü — "
                "tıklayarak öne getirebilirsiniz.",
            )
            sys.exit(0)
        QMessageBox.warning(
            None,
            APP_NAME,
            "Uygulama zaten açık görünüyor ama pencere bulunamadı.\n\n"
            "run.ps1'i tekrar çalıştırın (eski oturum kapatılır) veya "
            "Görev Yöneticisi'nden python.exe süreçlerini sonlandırın.",
        )
        sys.exit(1)

    window = MainWindow()
    window.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, False)
    window.showNormal()
    window.show()
    _center_on_screen(window)
    focus_window(window)
    QTimer.singleShot(150, lambda: focus_window(window))

    code = app.exec()
    instance.release()
    sys.exit(code)


if __name__ == "__main__":
    main()
