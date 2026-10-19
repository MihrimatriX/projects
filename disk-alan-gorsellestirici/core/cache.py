from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from core.models import ScanNode, is_same_or_under

APP_DIR = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "DiskAlanGorsellestirici"
DB_PATH = APP_DIR / "scan_cache.db"


def ensure_db() -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS scans (
                root_path TEXT PRIMARY KEY,
                root_mtime REAL NOT NULL,
                scanned_at TEXT NOT NULL,
                payload TEXT NOT NULL
            )
            """
        )


def _root_mtime(root: str) -> float:
    try:
        return Path(root).stat().st_mtime
    except OSError:
        return 0.0


def _cache_key(root: str, depth: int | None) -> str:
    # Derinlik limiti farklı taramalar aynı kök için ayrı saklanır; yoksa "Tam"
    # tarama, önceki "Hızlı (3)" sonucunu önbellekten döndürür.
    return f"{root}|depth={depth}"


def load_cached(root: str, depth: int | None = None) -> ScanNode | None:
    ensure_db()
    mtime = _root_mtime(root)
    with sqlite3.connect(DB_PATH) as conn:
        row = conn.execute(
            "SELECT root_mtime, payload FROM scans WHERE root_path = ?",
            (_cache_key(root, depth),),
        ).fetchone()
    if not row:
        return None
    cached_mtime, payload = row
    # Ucuz geçerlilik kontrolü: yalnızca kök klasörün mtime'ına bakılır (derindeki
    # değişiklikleri görmez). Tam güncel sonuç için "Burayı tara" önbelleği atlar.
    if abs(cached_mtime - mtime) > 1:
        return None
    return ScanNode.from_dict(json.loads(payload))


def save_cache(root: str, node: ScanNode, depth: int | None = None) -> None:
    ensure_db()
    payload = json.dumps(node.to_dict(), ensure_ascii=False)
    now = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            INSERT INTO scans (root_path, root_mtime, scanned_at, payload)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(root_path) DO UPDATE SET
                root_mtime = excluded.root_mtime,
                scanned_at = excluded.scanned_at,
                payload = excluded.payload
            """,
            (_cache_key(root, depth), _root_mtime(root), now, payload),
        )


def invalidate_cache_for(path: str) -> int:
    """path'i içeren tüm kök taramaların önbelleğini siler (çöpe taşıma sonrası
    F5 eski sonucu göstermesin). Silinen satır sayısını döndürür."""
    ensure_db()
    with sqlite3.connect(DB_PATH) as conn:
        keys = [k for (k,) in conn.execute("SELECT root_path FROM scans")]
        stale = [k for k in keys if is_same_or_under(path, k.rsplit("|depth=", 1)[0])]
        conn.executemany("DELETE FROM scans WHERE root_path = ?", [(k,) for k in stale])
    return len(stale)
