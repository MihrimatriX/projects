from PySide6.QtWidgets import QDialog, QLabel, QPushButton, QVBoxLayout

from utils.app_info import APP_NAME, APP_VERSION


class AboutDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle(f"Hakkında — {APP_NAME}")
        self.setMinimumWidth(360)
        layout = QVBoxLayout(self)
        layout.addWidget(
            QLabel(
                f"<h2>{APP_NAME}</h2>"
                f"<p>Sürüm {APP_VERSION}</p>"
                "<p>Hash tabanlı mükerrer dosya bulucu — dupeGuru / fdupes alternatifi.</p>"
                "<p><b>Üretim sürümü</b> — PySide6, yerel veri, telemetri yok.</p>"
                "<p>MIT Lisans</p>"
            )
        )
        btn = QPushButton("Kapat")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
