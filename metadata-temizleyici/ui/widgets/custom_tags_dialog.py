from __future__ import annotations

from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QLabel,
    QPlainTextEdit,
    QVBoxLayout,
)


def parse_tag_input(text: str) -> list[str]:
    tags: list[str] = []
    for line in text.replace(",", "\n").splitlines():
        name = line.strip()
        if name and name not in tags:
            tags.append(name)
    return tags


class CustomTagsDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Özel tag listesi")
        self.resize(420, 280)

        layout = QVBoxLayout(self)
        layout.addWidget(
            QLabel(
                "Silinecek tag adlarını girin (satır veya virgül ile).\n"
                "Örnek: GPSLatitude · Make · EXIF:Model"
            )
        )

        self.input = QPlainTextEdit()
        self.input.setPlaceholderText("GPSLatitude\nMake\nSerialNumber")
        layout.addWidget(self.input)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def tag_names(self) -> list[str]:
        return parse_tag_input(self.input.toPlainText())
