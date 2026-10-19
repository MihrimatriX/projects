from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QFrame, QLabel, QPushButton, QVBoxLayout


class EmptyStateWidget(QFrame):
    browse_clicked = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("EmptyState")
        outer = QVBoxLayout(self)
        outer.setAlignment(Qt.AlignmentFlag.AlignCenter)

        zone = QFrame()
        zone.setObjectName("DropZone")
        layout = QVBoxLayout(zone)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setSpacing(12)
        layout.setContentsMargins(48, 48, 48, 48)

        icon = QLabel("📁")
        icon.setObjectName("DropIcon")
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(icon)

        title = QLabel("Kök klasör ekleyin")
        title.setObjectName("DropTitle")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        hint = QLabel(
            "Taramaya başlamak için bir veya daha fazla klasör sürükleyin ya da gözatın."
        )
        hint.setObjectName("MutedLabel")
        hint.setWordWrap(True)
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(hint)

        btn = QPushButton("Klasör seç (Ctrl+O)")
        btn.setObjectName("PrimaryButton")
        btn.clicked.connect(self.browse_clicked.emit)
        layout.addWidget(btn, alignment=Qt.AlignmentFlag.AlignCenter)

        ipc = QLabel("İpucu: Disk Alanı Görselleştirici'den de klasör gönderebilirsiniz")
        ipc.setObjectName("MutedLabel")
        ipc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(ipc)

        outer.addWidget(zone)
