from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path

from PySide6.QtCore import QThread, Signal

from utils.audit import AuditEntry, AuditLog, now_iso
from utils.metadata import strip_metadata
from utils.models import StripResult
from utils.presets import StripMode

MAX_WORKERS = 3


@dataclass(frozen=True)
class BatchItemResult:
    path: Path
    success: bool
    tags_removed: int = 0
    message: str = ""
    backup: Path | None = None
    hash_changed: bool = False
    strip_result: StripResult | None = None


class BatchWorker(QThread):
    progress = Signal(int, int, str)
    item_done = Signal(object)
    finished_batch = Signal()

    def __init__(
        self,
        files: list[Path],
        *,
        backup: bool = True,
        overwrite: bool = True,
        mode: StripMode = StripMode.ALL,
        preset_id: str | None = None,
        custom_tags: list[str] | None = None,
        audit: AuditLog | None = None,
        dry_run: bool = False,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._files = files
        self._backup = backup
        self._overwrite = overwrite
        self._mode = mode
        self._preset_id = preset_id
        self._custom_tags = custom_tags
        self._audit = audit
        self._dry_run = dry_run
        self._cancelled = False

    def cancel(self) -> None:
        self._cancelled = True

    def _process_one(self, path: Path) -> BatchItemResult:
        result = strip_metadata(
            path,
            backup=self._backup,
            overwrite=self._overwrite,
            mode=self._mode,
            preset_id=self._preset_id,
            custom_tags=self._custom_tags,
            dry_run=self._dry_run,
        )
        if result.dry_run:
            msg = f"simülasyon: {result.tags_removed} tag silinirdi"
        else:
            msg = f"{result.tags_removed} tag silindi ({result.engine})"
            if result.hash_changed:
                msg += " · piksel verisi değişti"
        if self._audit and not self._dry_run:
            self._audit.add(
                AuditEntry(
                    timestamp=now_iso(),
                    file_path=str(path),
                    success=True,
                    tags_removed=result.tags_removed,
                    removed_tags="; ".join(result.removed_tag_names),
                    backup_path=str(result.backup or ""),
                    engine=result.engine,
                    mode=self._mode.value,
                    hash_changed=result.hash_changed,
                )
            )
        return BatchItemResult(
            path=path,
            success=True,
            tags_removed=result.tags_removed,
            message=msg,
            backup=result.backup,
            hash_changed=result.hash_changed,
            strip_result=result,
        )

    def run(self) -> None:
        # QThread içinde 3 iş parçacıklı havuz: dosyalar paralel temizlenir, sonuçlar
        # tamamlanma sırasıyla sinyal olarak GUI thread'ine gönderilir. İptal, kuyrukta
        # bekleyenleri düşürür; o an işlenen dosyalar yarıda kesilmez.
        total = len(self._files)
        completed = 0
        workers = min(MAX_WORKERS, max(1, total))

        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(self._process_one, path): path for path in self._files}
            for future in as_completed(futures):
                if self._cancelled:
                    pool.shutdown(wait=False, cancel_futures=True)
                    break
                path = futures[future]
                completed += 1
                self.progress.emit(completed, total, path.name)
                try:
                    self.item_done.emit(future.result())
                except Exception as exc:
                    self.item_done.emit(
                        BatchItemResult(
                            path=path,
                            success=False,
                            message=str(exc),
                        )
                    )
                    if self._audit:
                        self._audit.add(
                            AuditEntry(
                                timestamp=now_iso(),
                                file_path=str(path),
                                success=False,
                                tags_removed=0,
                                removed_tags="",
                                backup_path="",
                                engine="",
                                mode=self._mode.value,
                                hash_changed=False,
                                error=str(exc),
                            )
                        )

        self.finished_batch.emit()
