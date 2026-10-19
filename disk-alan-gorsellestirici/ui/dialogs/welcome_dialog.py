from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
)

from core.app_info import APP_NAME
from ui.theme import ACCENT, BG_PANEL, BORDER, PADDING_PANEL, TEXT_MUTED, TEXT_PRIMARY


class WelcomeDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Hoş geldiniz")
        self.setFixedWidth(520)
        self.setModal(True)
        self.pick_folder = False  # "Dizin Seç…" ile kapandıysa main.py klasör seçiciyi açar

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        titlebar = QLabel("Hoş geldiniz")
        titlebar.setStyleSheet(
            f"background: {BG_PANEL}; border-bottom: 1px solid {BORDER}; "
            f"padding: 10px 12px; font-size: 12px; color: {TEXT_MUTED};"
        )
        outer.addWidget(titlebar)

        content = QVBoxLayout()
        content.setContentsMargins(28, 32, 28, 28)
        content.setSpacing(0)

        icon = QLabel("◎")
        icon.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        icon.setStyleSheet(f"font-size: 48px; color: {ACCENT}; margin-bottom: 8px;")
        content.addWidget(icon)

        heading = QLabel(APP_NAME)
        heading.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        heading.setStyleSheet(
            f"font-size: 22px; font-weight: 700; color: {TEXT_PRIMARY}; letter-spacing: -0.02em;"
        )
        content.addWidget(heading)

        subtitle = QLabel(
            "DaisyDisk tarzı sunburst ile disk kullanımınızı görselleştirin, "
            "büyük dosyaları bulun, zaman içinde karşılaştırın."
        )
        subtitle.setWordWrap(True)
        subtitle.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        subtitle.setStyleSheet("font-size: 14px; line-height: 1.5; margin: 8px 0 28px;")
        content.addWidget(subtitle)

        steps = QFrame()
        steps.setStyleSheet(
            f"background: {BG_PANEL}; border: 1px solid {BORDER}; border-radius: 8px;"
        )
        steps_layout = QVBoxLayout(steps)
        steps_layout.setContentsMargins(18, 16, 18, 16)
        steps_layout.addWidget(QLabel(
            "1. Sürücü veya klasör seçin\n"
            "2. Tara — sunburst veya treemap görünümü\n"
            "3. Segmentlere tıklayarak alt klasörlere inin\n"
            "4. Dışa aktar ile rapor alın"
        ))
        tip = QLabel(
            'İpucu: Hızlı tarama için derinlik limitini 3 seçin. '
            "Backspace ile bir üst dizine çıkın."
        )
        tip.setWordWrap(True)
        tip.setStyleSheet(f"font-size: 12px; color: {TEXT_MUTED}; margin-top: 12px; padding-top: 12px; border-top: 1px solid {BORDER};")
        steps_layout.addWidget(tip)
        content.addWidget(steps)

        actions = QHBoxLayout()
        actions.setSpacing(10)
        actions.addStretch()
        start_btn = QPushButton("Başlayalım")
        start_btn.setObjectName("PrimaryButton")
        start_btn.clicked.connect(self.accept)
        folder_btn = QPushButton("Dizin Seç…")
        folder_btn.clicked.connect(self._pick)
        self.start_btn, self.folder_btn = start_btn, folder_btn
        actions.addWidget(start_btn)
        actions.addWidget(folder_btn)
        actions.addStretch()
        content.addSpacing(24)
        content.addLayout(actions)
        outer.addLayout(content)

    def _pick(self) -> None:
        self.pick_folder = True
        self.accept()
