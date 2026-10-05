from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDialog,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

STEPS = [
    {
        "blocks": [(1, True), (2, False)],
        "title": "Kural zinciri ile toplu yeniden adlandırma",
        "body": (
            "Sol panelde kuralları sıralayın; sağda canlı önizleme anında güncellenir. "
            "Regex, numaralandırma ve EXIF modları bir arada."
        ),
    },
    {
        "blocks": [(2, False), (1, True)],
        "title": "Canlı önizleme, çakışma uyarısı",
        "body": (
            "Her dosya için eski ve yeni adı görün. Çakışmalar kırmızı satır ile işaretlenir; "
            "uygulama butonu devre dışı kalır."
        ),
    },
    {
        "blocks": [(0.4, True), (0.6, False), (0.4, True)],
        "title": "Preset, makro ve geri al",
        "body": (
            "Hazır preset'lere tıklayarak zincire ekleyin. Ctrl+Z ile 20 adıma kadar geri alın. "
            "80+ dosyada arka plan önizlemesi devreye girer."
        ),
    },
]


class WelcomeDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Hoş geldiniz")
        self.setMinimumWidth(480)
        self.setModal(True)
        self._step = 0
        self._skip_next = True
        self._pages: list[QWidget] = []

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)

        body_wrap = QWidget()
        body_layout = QVBoxLayout(body_wrap)
        body_layout.setContentsMargins(32, 28, 32, 12)

        pages_host = QWidget()
        pages_host.setMinimumHeight(280)
        pages_grid = QGridLayout(pages_host)
        pages_grid.setContentsMargins(0, 0, 0, 0)
        for i, step in enumerate(STEPS):
            page = self._make_step(step)
            pages_grid.addWidget(page, 0, 0)
            page.setVisible(i == 0)
            self._pages.append(page)
        body_layout.addWidget(pages_host)
        root.addWidget(body_wrap)

        dots = QHBoxLayout()
        dots.setContentsMargins(32, 0, 32, 16)
        dots.addStretch()
        self._dot_buttons: list[QPushButton] = []
        for i in range(len(STEPS)):
            dot = QPushButton()
            dot.setObjectName("ModalDot")
            dot.setCheckable(True)
            dot.setChecked(i == 0)
            dot.setAccessibleName(f"Adım {i + 1}")
            dot.clicked.connect(lambda _=False, idx=i: self._goto(idx))
            self._dot_buttons.append(dot)
            dots.addWidget(dot)
        dots.addStretch()
        root.addLayout(dots)

        footer = QHBoxLayout()
        footer.setContentsMargins(32, 12, 32, 20)
        skip = QPushButton("Atla")
        skip.setObjectName("SkipLink")
        skip.setCursor(Qt.CursorShape.PointingHandCursor)
        skip.clicked.connect(self.accept)
        self.skip_btn = skip
        self.next_btn = QPushButton("İleri")
        self.next_btn.setObjectName("PrimaryButton")
        self.next_btn.clicked.connect(self._on_next)
        footer.addWidget(skip)
        footer.addStretch()
        footer.addWidget(self.next_btn)
        root.addLayout(footer)

    def _make_step(self, step: dict) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(0, 0, 0, 0)

        illus = QFrame()
        illus.setObjectName("ModalIllus")
        row = QHBoxLayout(illus)
        row.setContentsMargins(16, 16, 16, 16)
        row.setSpacing(12)
        for flex, accent in step["blocks"]:
            block = QFrame()
            block.setObjectName("ModalBlock")
            if accent:
                block.setProperty("accent", "true")
                block.style().unpolish(block)
                block.style().polish(block)
            row.addWidget(block, int(flex * 10) or 1)
        layout.addWidget(illus)

        title = QLabel(step["title"])
        title.setObjectName("ModalTitle")
        title.setWordWrap(True)
        layout.addWidget(title)

        body = QLabel(step["body"])
        body.setObjectName("ModalBody")
        body.setWordWrap(True)
        layout.addWidget(body)
        layout.addStretch()
        return page

    def _goto(self, index: int) -> None:
        self._step = index
        for i, page in enumerate(self._pages):
            page.setVisible(i == index)
        for i, dot in enumerate(self._dot_buttons):
            dot.setChecked(i == index)
        self.next_btn.setText("Başla" if index == len(STEPS) - 1 else "İleri")

    def _on_next(self) -> None:
        if self._step < len(STEPS) - 1:
            self._goto(self._step + 1)
        else:
            self.accept()

    def skip_next_time(self) -> bool:
        return self._skip_next
