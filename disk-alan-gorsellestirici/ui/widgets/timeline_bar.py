from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout

from core.formatters import human_size
from core.history import ScanSnapshot
from ui.theme import DANGER, SUCCESS, TEXT_SECONDARY as TEXT_MUTED  # #484f58 koyu zeminde okunmuyordu


class TimelineBar(QFrame):
    snapshot_selected = Signal(int)
    compare_toggled = Signal(bool)

    def __init__(self) -> None:
        super().__init__()
        self.setObjectName("TimelineBar")
        outer = QVBoxLayout(self)
        outer.setContentsMargins(16, 12, 16, 14)

        title = QLabel("ZAMAN MAKİNESİ")
        title.setObjectName("SectionTitle")
        outer.addWidget(title)

        self._dots_row = QHBoxLayout()
        self._dots_row.setSpacing(6)
        self._buttons: list[QPushButton] = []
        for i in range(4):
            btn = QPushButton()
            btn.setEnabled(False)
            btn.setObjectName("TimelineDot")
            btn.setFixedHeight(6)
            btn.setAccessibleName(f"Tarama {i + 1}")
            btn.clicked.connect(lambda _=False, idx=i: self._on_click(idx))
            self._buttons.append(btn)
            self._dots_row.addWidget(btn, stretch=1)
        outer.addLayout(self._dots_row)

        self._labels_row = QHBoxLayout()
        self._labels: list[QLabel] = []
        for _ in range(4):
            lbl = QLabel("—")
            lbl.setStyleSheet(f"font-size: 10px; color: {TEXT_MUTED};")
            self._labels.append(lbl)
            self._labels_row.addWidget(lbl, stretch=1)
        outer.addLayout(self._labels_row)

        self._snapshots: list[ScanSnapshot] = []
        self._active = -1

    def set_snapshots(self, snapshots: list[ScanSnapshot], *, current_size: int | None = None) -> None:
        self._snapshots = snapshots[-4:]
        for i, btn in enumerate(self._buttons):
            if i < len(self._snapshots):
                snap = self._snapshots[i]
                label = f"{snap.scanned_at[8:10]}.{snap.scanned_at[5:7]}"  # GG.AA
                if i == len(self._snapshots) - 1:
                    label = "Bugün"
                btn.setEnabled(True)
                btn.setToolTip(f"{human_size(snap.total_size)} · {snap.file_count:,} dosya")
                btn.setAccessibleName(f"Tarama {label}: {human_size(snap.total_size)}")
                self._labels[i].setText(label)
                if i > 0:
                    # Her nokta bir öncekine göre değişimi gösterir (önceden hepsi güncel boyutla kıyaslanıyordu).
                    delta = snap.total_size - self._snapshots[i - 1].total_size
                    sign = "+" if delta >= 0 else ""
                    color = DANGER if delta > 0 else SUCCESS
                    btn.setToolTip(
                        f"{btn.toolTip()}\n{sign}{human_size(abs(delta))}"
                    )
                    self._labels[i].setStyleSheet(f"font-size: 10px; color: {color};")
                else:
                    self._labels[i].setStyleSheet(f"font-size: 10px; color: {TEXT_MUTED};")
            else:
                btn.setEnabled(False)
                btn.setToolTip("")
                self._labels[i].setText("—")
                self._labels[i].setStyleSheet(f"font-size: 10px; color: {TEXT_MUTED};")

        self._highlight(len(self._snapshots) - 1 if self._snapshots else -1)

    def _highlight(self, index: int) -> None:
        self._active = index
        for i, btn in enumerate(self._buttons):
            btn.setObjectName("TimelineActive" if i == index else "TimelineDot")
            btn.setStyle(btn.style())

    def _on_click(self, index: int) -> None:
        if index >= len(self._snapshots):
            return
        self._highlight(index)
        self.snapshot_selected.emit(self._snapshots[index].id)
