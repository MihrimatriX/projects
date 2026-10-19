from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QThread, Signal

from utils.file_search import SearchResult, count_files, search_files
from utils.index_backend import build_index, get_index_stats
from utils.settings import background_scan_enabled, content_search_enabled, get_search_roots


def open_file(path: str) -> None:
    os.startfile(path)  # type: ignore[attr-defined]


def open_containing_folder(path: str) -> None:
    if sys.platform == "win32":
        subprocess.run(["explorer", "/select,", os.path.normpath(path)], check=False)
    else:
        os.startfile(os.path.dirname(path))  # type: ignore[attr-defined]


def format_roots_summary(roots: list[Path]) -> str:
    if not roots:
        return "Arama klasörü yok — ayarlardan ekleyin"

    def _short(p: Path) -> str:
        try:
            return "~/" + p.resolve().relative_to(Path.home()).as_posix()
        except ValueError:
            return str(p).replace("\\", "/")

    if len(roots) == 1:
        return _short(roots[0])

    shown = [_short(p) for p in roots[:3]]
    extra = f" +{len(roots) - 3}" if len(roots) > 3 else ""
    return " · ".join(shown) + extra


class IndexCountWorker(QThread):
    finished_count = Signal(int)

    def __init__(self, roots: list[Path], parent=None) -> None:
        super().__init__(parent)
        self._roots = roots

    def run(self) -> None:
        self.finished_count.emit(count_files(self._roots))


class SearchWorker(QThread):
    finished_search = Signal(object, int)
    failed = Signal(str)

    def __init__(self, roots: list[Path], query: str, file_type: str | None = None, parent=None) -> None:
        super().__init__(parent)
        self._roots = roots
        self._query = query
        self._file_type = file_type

    def run(self) -> None:
        try:
            results, elapsed = search_files(
                self._roots,
                self._query,
                search_content=content_search_enabled(),
                file_type=self._file_type,
            )
        except Exception as exc:  # her hata UI'a dönmeli; yoksa "Aranıyor…" takılı kalır
            self.failed.emit(str(exc))
            return
        self.finished_search.emit(results, elapsed)
        from utils.search_history import record_search

        record_search(self._query, len(results), elapsed)


class IndexBuildWorker(QThread):
    progress = Signal(int)
    finished_count = Signal(int)
    failed = Signal(str)

    def __init__(self, roots: list[Path], parent=None) -> None:
        super().__init__(parent)
        self._roots = roots
        self._cancel = False

    def cancel(self) -> None:
        self._cancel = True

    def run(self) -> None:
        if background_scan_enabled():
            self.setPriority(QThread.Priority.LowestPriority)
        try:
            count = build_index(
                self._roots,
                on_progress=lambda n: self.progress.emit(n),
                cancel_check=lambda: self._cancel,
            )
            self.finished_count.emit(count)
        except Exception as exc:
            self.failed.emit(str(exc))
