import sys
from pathlib import Path

from PySide6.QtGui import QFont, QIcon
from PySide6.QtWidgets import QApplication

from ui.main_window import MainWindow
from utils.config import APP_NAME, DEFAULT_HEIGHT, DEFAULT_WIDTH, MIN_HEIGHT, MIN_WIDTH


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
    app.setStyle("Fusion")

    font = QFont("Segoe UI Variable", 10)
    font.setHintingPreference(QFont.HintingPreference.PreferFullHinting)
    app.setFont(font)

    icon = _app_icon()
    if icon:
        app.setWindowIcon(icon)

    window = MainWindow()
    if icon:
        window.setWindowIcon(icon)
    window.setMinimumSize(MIN_WIDTH, MIN_HEIGHT)
    window.resize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
