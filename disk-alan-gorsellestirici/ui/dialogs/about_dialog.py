from PySide6.QtCore import Qt
from PySide6.QtWidgets import QDialog, QLabel, QPushButton, QVBoxLayout

from core.app_info import APP_NAME, APP_VERSION


class AboutDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Hakkında")
        self.setFixedSize(400, 280)
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("💾", alignment=Qt.AlignmentFlag.AlignHCenter))
        title = QLabel(APP_NAME)
        from ui.theme import TEXT_PRIMARY

        title.setStyleSheet(f"font-size:18px;font-weight:600;color:{TEXT_PRIMARY};")
        title.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        layout.addWidget(title)
        ver = QLabel(f"Sürüm {APP_VERSION}")
        ver.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        layout.addWidget(ver)
        desc = QLabel(
            "Windows için interaktif disk analizi.\n"
            "Sunburst, treemap, zaman makinesi, dışa aktarma.\n"
            "Veriler yalnızca yerel olarak saklanır."
        )
        desc.setWordWrap(True)
        desc.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        layout.addWidget(desc)
        btn = QPushButton("Tamam")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
