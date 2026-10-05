from __future__ import annotations

from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QProgressBar,
    QPushButton,
    QVBoxLayout,
)

from utils.formatters import human_size


class ScanPanel(QFrame):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("ScanProgressPanel")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)
        layout.setSpacing(10)

        top = QHBoxLayout()
        self.badge = QLabel("● Taranıyor")
        self.badge.setObjectName("ScanningBadge")
        top.addWidget(self.badge)
        top.addStretch()
        self.cancel_btn = QPushButton("İptal (Esc)")
        self.cancel_btn.setObjectName("DangerOutlineButton")
        self.cancel_btn.setEnabled(False)
        top.addWidget(self.cancel_btn)
        layout.addLayout(top)

        self.status_label = QLabel("Dosyalar toplanıyor…")
        self.status_label.setWordWrap(True)
        layout.addWidget(self.status_label)

        stats = QHBoxLayout()
        self.files_label = QLabel("0 dosya")
        self.files_label.setObjectName("MonoLabel")
        self.speed_label = QLabel("—")
        self.speed_label.setObjectName("MonoLabel")
        self.groups_label = QLabel("0 grup")
        self.groups_label.setObjectName("MonoLabel")
        for w in (self.files_label, self.speed_label, self.groups_label):
            stats.addWidget(w)
        stats.addStretch()
        layout.addLayout(stats)

        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setTextVisible(False)
        layout.addWidget(self.progress)

        self.savings_label = QLabel("")
        self.savings_label.setObjectName("SavingsLabel")
        self.savings_label.setVisible(False)
        layout.addWidget(self.savings_label)

        self._file_count = 0
        self.hide()

    def set_idle(self, _roots_text: str) -> None:
        self.hide()
        self.cancel_btn.setEnabled(False)
        self.savings_label.setVisible(False)

    def set_scanning(self, path: str, phase: str) -> None:
        self.show()
        phase_tr = {
            "collect": "Dosyalar toplanıyor",
            "partial": "Ön filtre",
            "full": "Hash doğrulama",
            "image": "Görsel benzerlik",
        }.get(phase, phase)
        short = path if len(path) <= 72 else "…" + path[-69:]
        self.status_label.setText(f"{short} — {phase_tr}")
        self.progress.setVisible(True)
        self.cancel_btn.setEnabled(True)

    def set_stats(self, files: int, speed: float, groups: int) -> None:
        self._file_count = files
        self.files_label.setText(f"{files:,} dosya")
        self.speed_label.setText(
            f"{speed:,.0f} dosya/s" if speed >= 1 else f"{speed:.2f} dosya/s"
        )
        # Toplam dosya sayısı baştan bilinmiyor: sahte yüzde yerine belirsiz ilerleme çubuğu yeterli.
        self.groups_label.setText(f"{groups} grup (canlı)")

    def set_complete(self, wasted: int, groups: int) -> None:
        self.hide()
        self.cancel_btn.setEnabled(False)
        if wasted > 0:
            self.savings_label.setText(f"Tahmini kazanç: {human_size(wasted)} — {groups} grup")
            self.savings_label.setVisible(True)
