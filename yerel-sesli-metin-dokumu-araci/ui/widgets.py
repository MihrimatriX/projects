"""Paylaşılan UI bileşenleri."""

from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor, QPainter, QPen
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from ui.theme import (
    ACCENT,
    BG_ELEVATED,
    BG_HOVER,
    TEXT_MUTED,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
    WAVE_PLAYED,
    WAVE_UNPLAYED,
)


class WaveformWidget(QWidget):
    seek_requested = Signal(float)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setMinimumHeight(80)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._progress = 0.0
        self._heights: list[float] = []  # gerçek ses tepe değerleri (0..1), transkripsiyon sonrası

    def set_peaks(self, peaks: list[float]) -> None:
        self._heights = list(peaks)
        self.update()

    def set_progress(self, ratio: float) -> None:
        self._progress = max(0.0, min(1.0, ratio))
        self.update()

    def paintEvent(self, _event) -> None:
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.fillRect(self.rect(), QColor(BG_ELEVATED))

        w, h = self.width(), self.height()
        bar_count = len(self._heights)
        if not bar_count:
            p.end()
            return
        gap = 2
        bar_w = max(2, (w - gap * (bar_count + 1)) / bar_count)
        played_idx = int(self._progress * bar_count)

        for i, frac in enumerate(self._heights):
            x = gap + i * (bar_w + gap)
            bh = max(4, frac * (h - 8))
            y = (h - bh) / 2
            color = WAVE_PLAYED if i < played_idx else WAVE_UNPLAYED
            p.fillRect(int(x), int(y), int(bar_w), int(bh), QColor(color))

        px = int(self._progress * w)
        p.setPen(QPen(QColor(TEXT_PRIMARY), 2))
        p.drawLine(px, 0, px, h)
        p.end()

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self.seek_requested.emit(event.position().x() / max(1, self.width()))
        super().mousePressEvent(event)


class InfoBanner(QFrame):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("OnlineBanner")
        row = QHBoxLayout(self)
        row.setContentsMargins(16, 10, 16, 10)
        msg = QLabel(
            "Tanıma tamamen bu bilgisayarda (Whisper) yapılır; ses hiçbir yere gönderilmez. "
            "Seçilen model ilk kullanımda bir kez indirilir: %LOCALAPPDATA%\\YerelSesliMetinDokumu\\models"
        )
        msg.setWordWrap(True)
        msg.setStyleSheet(f"color: {TEXT_PRIMARY}; font-weight: 500;")
        close = QPushButton("Kapat")
        close.setObjectName("IconBtn")
        close.clicked.connect(self._dismiss)
        row.addWidget(msg, stretch=1)
        row.addWidget(close)

    def _dismiss(self) -> None:
        self.hide()


class NavToolbar(QFrame):
    page_changed = Signal(int)
    open_file = Signal()
    toggle_sidebar = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("Toolbar")
        row = QHBoxLayout(self)
        row.setContentsMargins(16, 0, 16, 0)

        brand = QLabel("Sesli Metin Dökümü")
        brand.setStyleSheet("font-size: 15px; font-weight: 600;")

        self._nav: list[QPushButton] = []
        nav_box = QHBoxLayout()
        nav_box.setSpacing(4)
        for i, label in enumerate(("Ana alan", "Geçmiş")):
            btn = QPushButton(label)
            btn.setObjectName("NavBtn")
            btn.setCheckable(True)
            btn.clicked.connect(lambda _=False, idx=i: self._select(idx))
            self._nav.append(btn)
            nav_box.addWidget(btn)

        actions = QHBoxLayout()
        actions.setSpacing(8)
        open_btn = QPushButton("📂")
        open_btn.setObjectName("IconBtn")
        open_btn.setToolTip("Dosya aç (Ctrl+O)")
        open_btn.clicked.connect(self.open_file.emit)
        hist_btn = QPushButton("🕐")
        hist_btn.setObjectName("IconBtn")
        hist_btn.setToolTip("Geçmiş paneli")
        hist_btn.clicked.connect(self.toggle_sidebar.emit)
        actions.addWidget(open_btn)
        actions.addWidget(hist_btn)

        row.addWidget(brand)
        row.addSpacing(12)
        row.addLayout(nav_box, stretch=1)
        row.addLayout(actions)
        self._select(0)

    def _select(self, idx: int) -> None:
        for i, btn in enumerate(self._nav):
            btn.setChecked(i == idx)
        self.page_changed.emit(idx)

    def set_page(self, idx: int) -> None:
        self._select(idx)


class SegmentRow(QFrame):
    clicked = Signal(float)

    def __init__(self, start_sec: float, text: str, parent=None) -> None:
        super().__init__(parent)
        self._start = start_sec
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("QFrame { border-left: 2px solid transparent; }")
        row = QHBoxLayout(self)
        row.setContentsMargins(20, 10, 20, 10)
        from utils.time_fmt import format_duration

        time_l = QLabel(format_duration(start_sec))
        time_l.setObjectName("Mono")
        time_l.setFixedWidth(48)
        body = QLabel(text)
        body.setWordWrap(True)
        body.setStyleSheet(f"color: {TEXT_PRIMARY}; font-size: 15px;")
        row.addWidget(time_l)
        row.addWidget(body, stretch=1)

    def set_active(self, active: bool) -> None:
        border = ACCENT if active else "transparent"
        bg = BG_HOVER if active else "transparent"
        self.setStyleSheet(
            f"QFrame {{ border-left: 2px solid {border}; background: {bg}; }}"
        )

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self.clicked.emit(self._start)
        super().mousePressEvent(event)
