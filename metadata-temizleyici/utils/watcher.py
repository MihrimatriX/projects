from __future__ import annotations

import time
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from utils.audit import AuditEntry, AuditLog, now_iso
from utils.metadata import is_supported, strip_metadata
from utils.models import StripResult
from utils.presets import StripMode

_SETTLE_SECONDS = 0.4


class MetadataWatchHandler(FileSystemEventHandler):
    def __init__(
        self,
        *,
        backup: bool,
        mode: StripMode,
        preset_id: str | None,
        custom_tags: list[str] | None = None,
        audit: AuditLog | None,
        on_processed=None,
    ) -> None:
        super().__init__()
        self._backup = backup
        self._mode = mode
        self._preset_id = preset_id
        self._custom_tags = custom_tags
        self._audit = audit
        self._on_processed = on_processed

    def on_created(self, event) -> None:
        if event.is_directory:
            return
        path = Path(event.src_path)
        if not is_supported(path):
            return
        time.sleep(_SETTLE_SECONDS)
        if not path.is_file():
            return
        try:
            result = strip_metadata(
                path,
                backup=self._backup,
                mode=self._mode,
                preset_id=self._preset_id,
                custom_tags=self._custom_tags,
            )
            self._record_audit(path, result, success=True)
            if self._on_processed:
                self._on_processed(path, result)
        except Exception as exc:
            self._record_audit(path, None, success=False, error=str(exc))
            if self._on_processed:
                self._on_processed(path, exc)

    def _record_audit(
        self,
        path: Path,
        result: StripResult | None,
        *,
        success: bool,
        error: str = "",
    ) -> None:
        if not self._audit:
            return
        self._audit.add(
            AuditEntry(
                timestamp=now_iso(),
                file_path=str(path),
                success=success,
                tags_removed=result.tags_removed if result else 0,
                removed_tags="; ".join(result.removed_tag_names) if result else "",
                backup_path=str(result.backup or "") if result else "",
                engine=result.engine if result else "",
                mode=self._mode.value,
                hash_changed=result.hash_changed if result else False,
                error=error,
            )
        )


class FolderWatcher:
    def __init__(self) -> None:
        self._observer: Observer | None = None
        self._directory: str = ""

    @property
    def active(self) -> bool:
        return self._observer is not None and self._observer.is_alive()

    @property
    def directory(self) -> str:
        return self._directory

    def start(
        self,
        directory: str,
        *,
        backup: bool,
        mode: StripMode,
        preset_id: str | None,
        custom_tags: list[str] | None = None,
        audit: AuditLog | None,
        on_processed=None,
    ) -> None:
        self.stop()
        path = Path(directory)
        if not path.is_dir():
            raise NotADirectoryError(directory)

        handler = MetadataWatchHandler(
            backup=backup,
            mode=mode,
            preset_id=preset_id,
            custom_tags=custom_tags,
            audit=audit,
            on_processed=on_processed,
        )
        self._observer = Observer()
        self._observer.schedule(handler, str(path), recursive=True)
        self._observer.start()
        self._directory = str(path)

    def stop(self) -> None:
        if self._observer:
            self._observer.stop()
            self._observer.join(timeout=3)
            self._observer = None
        self._directory = ""
