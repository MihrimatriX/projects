from __future__ import annotations

import sys

from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication

from utils.app_paths import asset_path


def _register_heif() -> None:
    try:
        import pillow_heif

        pillow_heif.register_heif_opener()
    except ImportError:
        pass


def _app_icon() -> QIcon | None:
    for name in ("app.ico", "icon.ico", "icon.png"):
        path = asset_path(name)
        if path.is_file():
            return QIcon(str(path))
    return None


def main() -> None:
    _register_heif()
    from ui.main_window import MainWindow

    app = QApplication(sys.argv)
    app.setApplicationName("Metadata Temizleyici")
    app.setQuitOnLastWindowClosed(False)

    icon = _app_icon()
    if icon:
        app.setWindowIcon(icon)

    window = MainWindow()
    if icon:
        window.setWindowIcon(icon)
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
