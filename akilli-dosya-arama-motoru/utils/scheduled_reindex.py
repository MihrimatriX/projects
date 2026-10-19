"""Zamanlanmış FTS5 yeniden indeksleme — Faz 3."""

from __future__ import annotations

import time
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, Signal

from utils.actions import IndexBuildWorker
from utils.settings import get_search_roots, scheduled_reindex_enabled, scheduled_reindex_hour


class ScheduledReindexService(QObject):
    """Her gün belirlenen saatte bir kez tam indeks oluşturur."""

    started = Signal()
    finished = Signal(int)
    failed = Signal(str)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._worker: IndexBuildWorker | None = None
        self._last_run_date = ""
        self._timer = QTimer(self)
        self._timer.setInterval(60_000)
        self._timer.timeout.connect(self._tick)

    def start(self) -> None:
        self._timer.start()
        self._tick()

    def stop(self) -> None:
        self._timer.stop()
        if self._worker and self._worker.isRunning():
            self._worker.cancel()
            self._worker.wait(2000)  # çalışan QThread yok edilirse uygulama çöker

    def _tick(self) -> None:
        if not scheduled_reindex_enabled():
            return
        if self._worker and self._worker.isRunning():
            return

        today = time.strftime("%Y-%m-%d")
        if self._last_run_date == today:
            return

        hour = scheduled_reindex_hour()
        if time.localtime().tm_hour != hour:
            return

        roots = get_search_roots()
        if not roots:
            return

        self._last_run_date = today
        self.started.emit()
        self._worker = IndexBuildWorker(roots, self)
        self._worker.finished_count.connect(self._on_done)
        self._worker.failed.connect(self.failed.emit)
        self._worker.start()

    def _on_done(self, count: int) -> None:
        self.finished.emit(count)
        self._worker = None
