import sys
from pathlib import Path

from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication

from ui.main_window import MainWindow

ASSETS = Path(__file__).resolve().parent / "assets"


def _app_icon() -> QIcon | None:
    for name in ("icon.ico", "icon.png"):
        path = ASSETS / name
        if path.exists():
            return QIcon(str(path))
    return None


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("Sesli Metin Dökümü")
    icon = _app_icon()
    if icon:
        app.setWindowIcon(icon)
    window = MainWindow()
    if icon:
        window.setWindowIcon(icon)
    window.show()
    # "Birlikte aç" / exe'ye sürükle-bırak: komut satırındaki ses dosyası hemen dökülür
    if len(sys.argv) > 1 and Path(sys.argv[1]).is_file():
        window._open_job_in_workspace(sys.argv[1])
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
