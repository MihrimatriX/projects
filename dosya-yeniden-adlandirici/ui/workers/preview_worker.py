from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QThread, Signal

from core.models import Rule
from core.rules_engine import compute_preview


class PreviewWorker(QThread):
    finished = Signal(object, object)
    progress = Signal(int, int)

    def __init__(
        self,
        files: list[Path],
        rules: list[Rule],
        *,
        exif_mtime_fallback_default: bool,
    ) -> None:
        super().__init__()
        self._files = files
        self._rules = rules
        self._exif_default = exif_mtime_fallback_default
        self._cancelled = False

    def cancel(self) -> None:
        self._cancelled = True

    def run(self) -> None:
        rows, err = compute_preview(
            self._files,
            self._rules,
            exif_mtime_fallback_default=self._exif_default,
            should_cancel=lambda: self._cancelled,
            on_progress=lambda done, total: self.progress.emit(done, total),
        )
        self.finished.emit(rows, err)
