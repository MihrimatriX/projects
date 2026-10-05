from __future__ import annotations

from PySide6.QtCore import QThread, Signal

from utils.duplicates import find_duplicates
from utils.models import ScanSettings
from utils.scan_cache import load_cached, save_cache


class ScanWorker(QThread):
    progress = Signal(str, int, str, int)
    finished_ok = Signal(list, bool)
    finished_error = Signal(str)
    finished_cancelled = Signal()

    def __init__(self, settings: ScanSettings, *, use_cache: bool = True) -> None:
        super().__init__()
        self.settings = settings
        self.use_cache = use_cache
        self._cancel = False

    def cancel(self) -> None:
        self._cancel = True

    def run(self) -> None:
        try:
            if self.use_cache:
                cached = load_cached(self.settings)
                if cached is not None:
                    self.finished_ok.emit(cached, True)
                    return

            def on_progress(phase: str, count: int, path: str, groups: int) -> None:
                self.progress.emit(phase, count, path, groups)

            groups = find_duplicates(
                self.settings,
                on_progress=on_progress,
                should_cancel=lambda: self._cancel,
            )
            if self._cancel:
                self.finished_cancelled.emit()
                return

            if self.use_cache:
                save_cache(self.settings, groups)
            self.finished_ok.emit(groups, False)
        except FileNotFoundError as exc:
            self.finished_error.emit(str(exc))
        except Exception as exc:  # noqa: BLE001
            self.finished_error.emit(str(exc))
