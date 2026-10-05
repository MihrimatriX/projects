from __future__ import annotations

import csv
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class AuditEntry:
    timestamp: str
    file_path: str
    success: bool
    tags_removed: int
    removed_tags: str
    backup_path: str
    engine: str
    mode: str
    hash_changed: bool
    error: str = ""


@dataclass
class AuditLog:
    entries: list[AuditEntry] = field(default_factory=list)

    def add(self, entry: AuditEntry) -> None:
        self.entries.append(entry)

    def clear(self) -> None:
        self.entries.clear()

    def export_csv(self, dest: Path) -> None:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open("w", newline="", encoding="utf-8-sig") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=[
                    "timestamp",
                    "file_path",
                    "success",
                    "tags_removed",
                    "removed_tags",
                    "backup_path",
                    "engine",
                    "mode",
                    "hash_changed",
                    "error",
                ],
            )
            writer.writeheader()
            for entry in self.entries:
                writer.writerow(
                    {
                        "timestamp": entry.timestamp,
                        "file_path": entry.file_path,
                        "success": "evet" if entry.success else "hayır",
                        "tags_removed": entry.tags_removed,
                        "removed_tags": entry.removed_tags,
                        "backup_path": entry.backup_path,
                        "engine": entry.engine,
                        "mode": entry.mode,
                        "hash_changed": "evet" if entry.hash_changed else "hayır",
                        "error": entry.error,
                    }
                )


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
