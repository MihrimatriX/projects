"""FS watcher — FTS5 delta indeks güncellemesi (Faz 2)."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, QTimer, Signal
from watchdog.events import FileSystemEventHandler, FileSystemMovedEvent
from watchdog.observers import Observer

from utils.excludes import should_skip_file
from utils.index_backend import DeltaEvent, apply_delta_batch
from utils.settings import get_search_roots, watcher_enabled


def _resolve(path: str) -> Path | None:
    try:
        return Path(path).expanduser().resolve()
    except OSError:
        return None


# watchdog olayları kendi thread'inde gelir; Qt sinyali (kuyruklu bağlantı) ile ana
# thread'e taşınır, _pending'de biriktirilir ve 750 ms sessizlikten sonra tek
# seferde FTS5'e yazılır (debounce).
class _EventBridge(QObject):
    fs_event = Signal(str, str, str)  # kind, src, dest


class _Handler(FileSystemEventHandler):
    def __init__(self, bridge: _EventBridge) -> None:
        super().__init__()
        self._bridge = bridge

    def on_created(self, event) -> None:
        if event.is_directory:
            return
        self._bridge.fs_event.emit("add", event.src_path, "")

    def on_modified(self, event) -> None:
        if event.is_directory:
            return
        self._bridge.fs_event.emit("add", event.src_path, "")

    def on_deleted(self, event) -> None:
        if event.is_directory:
            self._bridge.fs_event.emit("del_tree", event.src_path, "")
        else:
            self._bridge.fs_event.emit("del", event.src_path, "")

    def on_moved(self, event: FileSystemMovedEvent) -> None:
        if event.is_directory:
            self._bridge.fs_event.emit("del_tree", event.src_path, "")
            return
        self._bridge.fs_event.emit("move", event.src_path, event.dest_path)


class IndexWatcher(QObject):
    """Arama köklerini izler; debounced delta indeks yazar."""

    indexing = Signal(bool)
    index_count_changed = Signal(int)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._observer: Observer | None = None
        self._bridge = _EventBridge()
        self._bridge.fs_event.connect(self._on_fs_event)
        self._handler = _Handler(self._bridge)
        self._roots: list[Path] = []
        self._pending: list[DeltaEvent] = []
        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(750)
        self._debounce.timeout.connect(self._flush)

    def start(self, roots: list[Path] | None = None) -> None:
        self.stop()
        if not watcher_enabled():
            return

        self._roots = list(roots or get_search_roots())
        if not self._roots:
            return

        self._observer = Observer()
        for root in self._roots:
            if root.is_dir():
                self._observer.schedule(self._handler, str(root), recursive=True)
        self._observer.start()

    def stop(self) -> None:
        if self._observer is not None:
            self._observer.stop()
            self._observer.join(timeout=2)
            self._observer = None
        self._pending.clear()
        self._debounce.stop()

    def restart(self, roots: list[Path] | None = None) -> None:
        self.start(roots)

    def _under_roots(self, path: Path) -> bool:
        for root in self._roots:
            try:
                path.relative_to(root)
                return True
            except ValueError:
                continue
        return False

    def _on_fs_event(self, kind: str, src: str, dest: str) -> None:
        if kind == "move":
            src_p = _resolve(src)
            dest_p = _resolve(dest)
            if dest_p and self._under_roots(dest_p):
                if dest_p.is_file() and not should_skip_file(dest_p):
                    self._pending.append(("move", src, dest))
            elif src_p and self._under_roots(src_p):
                self._pending.append(("del", src))
        elif kind == "del_tree":
            src_p = _resolve(src)
            if src_p and self._under_roots(src_p):
                self._pending.append(("del_tree", src))
        elif kind == "del":
            src_p = _resolve(src)
            if src_p and self._under_roots(src_p):
                self._pending.append(("del", src))
        elif kind == "add":
            src_p = _resolve(src)
            if src_p and self._under_roots(src_p) and src_p.is_file():
                if not should_skip_file(src_p):
                    self._pending.append(("add", src))

        if self._pending:
            self._debounce.start()

    def _flush(self) -> None:
        if not self._pending:
            return
        batch = self._pending[:]
        self._pending.clear()
        self.indexing.emit(True)
        try:
            count = apply_delta_batch(batch)
            self.index_count_changed.emit(count)
        except Exception as exc:
            import sys

            print(f"FTS5 delta hatası: {exc}", file=sys.stderr)
        finally:
            self.indexing.emit(False)
