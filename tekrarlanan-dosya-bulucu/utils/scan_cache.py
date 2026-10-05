from __future__ import annotations

import gc
import hashlib
import json
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path

from utils.models import DuplicateFile, DuplicateGroup, ScanSettings
from utils.settings import APP_DIR

DB_PATH = APP_DIR / "scan_cache.db"


def _settings_signature(settings: ScanSettings) -> str:
    payload = {
        "roots": sorted(settings.roots),
        "min_size": settings.min_size_bytes,
        "exts": sorted(settings.exclude_extensions),
        "skip_hidden": settings.skip_hidden,
        "skip_system": settings.skip_system_dirs,
        "follow_symlinks": settings.follow_symlinks,
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def _roots_mtime_map(roots: list[str]) -> dict[str, float]:
    result: dict[str, float] = {}
    for root in roots:
        try:
            result[root] = Path(root).resolve().stat().st_mtime
        except OSError:
            result[root] = 0.0
    return result


def ensure_db() -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS duplicate_scans (
                cache_key TEXT PRIMARY KEY,
                roots_mtime TEXT NOT NULL,
                scanned_at TEXT NOT NULL,
                payload TEXT NOT NULL
            )
            """
        )


def _groups_to_json(groups: list[DuplicateGroup]) -> str:
    data = [
        {
            "hash_hex": g.hash_hex,
            "size": g.size,
            "is_hardlink_group": g.is_hardlink_group,
            "files": [
                {
                    "path": f.path,
                    "size": f.size,
                    "mtime": f.mtime,
                    "inode": f.inode,
                    "device": f.device,
                    "marked_for_delete": f.marked_for_delete,
                    "is_keeper": f.is_keeper,
                    "preview": f.preview,
                }
                for f in g.files
            ],
        }
        for g in groups
    ]
    return json.dumps(data, ensure_ascii=False)


def _groups_from_json(payload: str) -> list[DuplicateGroup]:
    groups: list[DuplicateGroup] = []
    for item in json.loads(payload):
        files = [DuplicateFile(**f) for f in item["files"]]
        groups.append(
            DuplicateGroup(
                hash_hex=item["hash_hex"],
                size=item["size"],
                files=files,
                is_hardlink_group=item.get("is_hardlink_group", False),
            )
        )
    return groups


def load_cached(settings: ScanSettings) -> list[DuplicateGroup] | None:
    ensure_db()
    key = _settings_signature(settings)
    current_mt = _roots_mtime_map(settings.roots)
    with sqlite3.connect(DB_PATH) as conn:
        row = conn.execute(
            "SELECT roots_mtime, payload FROM duplicate_scans WHERE cache_key = ?",
            (key,),
        ).fetchone()
    if not row:
        return None
    stored_mt = json.loads(row[0])
    if stored_mt != current_mt:
        return None
    groups = _groups_from_json(row[1])
    # Kök mtime'ı alt klasörlerdeki silme/değişikliği görmez; önbellekteki her dosya
    # hâlâ aynı boyut/mtime ile duruyor mu kontrol et, değilse yeniden tara.
    # ponytail: alt klasörlere yeni eklenen kopyalar yakalanmaz; gerekirse "Önbelleği temizle"
    for group in groups:
        for f in group.files:
            try:
                st = Path(f.path).stat()
            except OSError:
                return None
            if st.st_size != f.size or st.st_mtime != f.mtime:
                return None
    return groups


def save_cache(settings: ScanSettings, groups: list[DuplicateGroup]) -> None:
    ensure_db()
    key = _settings_signature(settings)
    now = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            INSERT INTO duplicate_scans (cache_key, roots_mtime, scanned_at, payload)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(cache_key) DO UPDATE SET
                roots_mtime = excluded.roots_mtime,
                scanned_at = excluded.scanned_at,
                payload = excluded.payload
            """,
            (
                key,
                json.dumps(_roots_mtime_map(settings.roots)),
                now,
                _groups_to_json(groups),
            ),
        )


def clear_cache() -> bool:
    if not DB_PATH.exists():
        return False
    # ponytail: Windows SQLite close sonrası handle GC'ye kalabiliyor (WinError 32)
    for _ in range(8):
        gc.collect()
        try:
            DB_PATH.unlink()
            return True
        except PermissionError:
            time.sleep(0.05)
    return False
