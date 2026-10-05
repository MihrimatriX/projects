from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QPushButton, QWidget

from core.models import ScanNode


class BreadcrumbBar(QWidget):
    navigated = Signal(object)

    def __init__(self) -> None:
        super().__init__()
        self._trail: list[ScanNode] = []
        self._layout = QHBoxLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(4)
        self._rebuild()  # boş durum ("Henüz tarama yok") açılışta da görünsün

    def set_trail(self, trail: list[ScanNode]) -> None:
        self._trail = trail
        self._rebuild()

    def _rebuild(self) -> None:
        while self._layout.count():
            item = self._layout.takeAt(0)
            if item.widget():
                item.widget().hide()  # deleteLater'a kadar eski düğmeler görünmesin
                item.widget().deleteLater()

        if not self._trail:
            lbl = QLabel("Henüz tarama yok")
            lbl.setObjectName("MutedLabel")
            self._layout.addWidget(lbl)
            self._layout.addStretch()
            return

        for idx, node in enumerate(self._trail):
            if idx > 0:
                sep = QLabel("›")
                sep.setObjectName("MutedLabel")
                self._layout.addWidget(sep)

            is_last = idx == len(self._trail) - 1
            btn = QPushButton(node.name)
            btn.setFlat(True)
            btn.setObjectName("BreadcrumbCurrent" if is_last else "BreadcrumbLink")
            if not is_last:
                btn.clicked.connect(lambda _=False, i=idx: self._go(i))
            self._layout.addWidget(btn)

        self._layout.addStretch()

    def _go(self, index: int) -> None:
        if 0 <= index < len(self._trail):
            self.navigated.emit(self._trail[index])
