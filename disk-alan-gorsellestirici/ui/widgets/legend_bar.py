from __future__ import annotations

from PySide6.QtWidgets import QFrame, QGridLayout, QHBoxLayout, QLabel

from ui.theme import CATEGORY_COLORS, PADDING_PANEL, SEG_OTHER, TEXT_SECONDARY


class LegendBar(QFrame):
    def __init__(self) -> None:
        super().__init__()
        # 3 sütunlu ızgara: tek satırda 320 px'lik panele sığmıyor, etiketler kırpılıyordu.
        layout = QGridLayout(self)
        layout.setContentsMargins(PADDING_PANEL, 12, PADDING_PANEL, 12)
        layout.setHorizontalSpacing(12)
        layout.setVerticalSpacing(6)

        labels = {
            "code": "Kod",
            "video": "Video",
            "image": "Görsel",
            "document": "Belge",
            "cloud": "Bulut",
            "system": "Sistem",
        }
        for i, (key, text) in enumerate(labels.items()):
            row = QHBoxLayout()
            row.setSpacing(5)
            swatch = QLabel()
            swatch.setFixedSize(8, 8)
            color = CATEGORY_COLORS.get(key, SEG_OTHER)
            swatch.setStyleSheet(
                f"background: {color}; border-radius: 2px;"
            )
            lbl = QLabel(text)
            lbl.setStyleSheet(f"font-size: 11px; color: {TEXT_SECONDARY};")
            row.addWidget(swatch)
            row.addWidget(lbl)
            row.addStretch()
            layout.addLayout(row, i // 3, i % 3)
