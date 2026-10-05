from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QDragEnterEvent, QDropEvent, QMouseEvent
from PySide6.QtWidgets import QFileDialog, QFrame, QLabel, QVBoxLayout

from utils.metadata import collect_files


class DropZone(QFrame):
    files_dropped = Signal(list)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("DropZone")
        self.setAcceptDrops(True)
        self.setMinimumHeight(140)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        icon = QLabel("📁")
        icon.setObjectName("DropIcon")
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)

        title = QLabel("Dosya sürükleyin veya klasör seçin")
        title.setObjectName("DropTitle")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)

        hint = QLabel("Klasör temizleme alt klasörleri dahil tarar; dosya türü filtresi uygulanmaz.")
        hint.setObjectName("DropHint")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(icon)
        layout.addWidget(title)
        layout.addWidget(hint)

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self._pick_files()
        super().mousePressEvent(event)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self.setProperty("dragOver", True)
            self.style().unpolish(self)
            self.style().polish(self)

    def dragLeaveEvent(self, event) -> None:
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
        super().dragLeaveEvent(event)

    def dropEvent(self, event: QDropEvent) -> None:
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
        paths = [url.toLocalFile() for url in event.mimeData().urls() if url.isLocalFile()]
        if paths:
            self.files_dropped.emit(paths)
        event.acceptProposedAction()

    def pick_files(self) -> None:
        self._pick_files()

    def _pick_files(self) -> None:
        dialog = QFileDialog(self, "Dosya veya klasör seç")
        dialog.setFileMode(QFileDialog.FileMode.ExistingFiles)
        dialog.setNameFilter(
            "Desteklenen (*.jpg *.jpeg *.png *.webp *.tiff *.tif *.bmp *.heic *.heif *.pdf "
            "*.mp4 *.mov *.avi *.mkv *.m4v *.webm *.wmv *.3gp)"
        )
        if dialog.exec():
            selected = dialog.selectedFiles()
            if selected:
                self.files_dropped.emit(selected)

    @staticmethod
    def resolve_paths(paths: list[str]) -> list[Path]:
        return collect_files(paths)
