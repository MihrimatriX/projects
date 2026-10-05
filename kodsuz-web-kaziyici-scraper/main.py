import sys
from pathlib import Path

from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication

from ui.main_window import MainWindow

ASSETS = Path(__file__).resolve().parent / "assets"


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("Kodsuz Web Kazıyıcı")

    icon_file = next((p for p in (ASSETS / "app.ico", ASSETS / "icon.png") if p.exists()), None)
    if icon_file:
        app.setWindowIcon(QIcon(str(icon_file)))

    window = MainWindow()
    if icon_file:
        window.setWindowIcon(QIcon(str(icon_file)))
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
