from __future__ import annotations

from PySide6.QtWidgets import QDialog, QLabel, QVBoxLayout

from core.app_info import APP_NAME, APP_VERSION
from ui.theme import TEXT_MUTED


class AboutDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Hakkında")
        self.setMinimumWidth(360)
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel(f"<h2>{APP_NAME}</h2>"))
        layout.addWidget(QLabel(f"Sürüm {APP_VERSION}"))
        layout.addWidget(
            QLabel(
                "<p>Toplu dosya yeniden adlandırma — kural zinciri, regex ve canlı önizleme.</p>"
                f"<p style='color:{TEXT_MUTED}'>Python · PySide6 · Yerel veri</p>"
            )
        )
