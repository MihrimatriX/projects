from __future__ import annotations

from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QVBoxLayout

from utils.formatters import human_size


class SavingsBanner(QFrame):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("SavingsBanner")
        layout = QHBoxLayout(self)
        layout.setContentsMargins(20, 14, 20, 14)
        layout.setSpacing(16)

        self.amount = QLabel("0 B")
        self.amount.setObjectName("SavingsAmount")
        layout.addWidget(self.amount)

        meta_box = QVBoxLayout()
        meta_box.setSpacing(2)
        self.meta = QLabel("")
        self.meta.setObjectName("SavingsMeta")
        self.meta.setWordWrap(True)
        sub = QLabel("Güvenli silme: dosyalar çöp kutusuna taşınır")
        sub.setObjectName("MutedLabel")
        meta_box.addWidget(self.meta)
        meta_box.addWidget(sub)
        layout.addLayout(meta_box, stretch=1)

    def set_stats(self, wasted: int, groups: int, selectable: int) -> None:
        self.amount.setText(human_size(wasted))
        self.meta.setText(
            f"<b>{groups} mükerrer grup</b> · {selectable} dosya seçilebilir"
        )
