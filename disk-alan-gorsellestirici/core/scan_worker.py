from __future__ import annotations

import string
from pathlib import Path

from PySide6.QtCore import QThread, Signal

from core.cache import load_cached, save_cache
from core.history import append_history
from core.models import LargeFile, ScanNode
from core.scanner import DirectoryScanner, large_files_in


class ScanWorker(QThread):
    progress = Signal(int, str)
    finished_ok = Signal(object, list)
    finished_error = Signal(str)

    def __init__(self, root: str, *, max_depth: int | None = None, use_cache: bool = True) -> None:
        super().__init__()
        self.root = root
        self.max_depth = max_depth
        self.use_cache = use_cache
        self._cancel = False

    def cancel(self) -> None:
        self._cancel = True

    def run(self) -> None:
        try:
            if self.use_cache:
                cached = load_cached(self.root, self.max_depth)
                if cached is not None:
                    self.finished_ok.emit(cached, large_files_in(cached))
                    return

            scanner = DirectoryScanner(
                max_depth=self.max_depth,
                on_progress=lambda count, path: self.progress.emit(count, path),
                should_cancel=lambda: self._cancel,
            )
            node = scanner.scan(self.root)
            if self._cancel:
                return
            save_cache(self.root, node, self.max_depth)
            append_history(self.root, node)
            self.finished_ok.emit(node, scanner.large_files)
        except Exception as exc:  # noqa: BLE001
            self.finished_error.emit(str(exc))


def list_windows_drives() -> list[str]:
    drives: list[str] = []
    for letter in string.ascii_uppercase:
        path = f"{letter}:\\"
        if Path(path).exists():
            drives.append(path)
    return drives
