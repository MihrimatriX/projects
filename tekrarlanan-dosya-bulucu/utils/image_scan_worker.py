from __future__ import annotations

from PySide6.QtCore import QThread, Signal

from utils.image_similarity import find_similar_images
from utils.models import ScanSettings


class ImageScanWorker(QThread):
    progress = Signal(str, int, str, int)
    finished_ok = Signal(list)
    finished_error = Signal(str)
    finished_cancelled = Signal()

    def __init__(self, settings: ScanSettings) -> None:
        super().__init__()
        self.settings = settings
        self._cancel = False

    def cancel(self) -> None:
        self._cancel = True

    def run(self) -> None:
        try:

            def on_progress(phase: str, count: int, path: str, groups: int) -> None:
                self.progress.emit(phase, count, path, groups)

            groups = find_similar_images(
                self.settings,
                on_progress=on_progress,
                should_cancel=lambda: self._cancel,
            )
            if self._cancel:
                self.finished_cancelled.emit()
                return
            self.finished_ok.emit(groups)
        except RuntimeError as exc:
            self.finished_error.emit(str(exc))
        except Exception as exc:  # noqa: BLE001
            self.finished_error.emit(str(exc))
