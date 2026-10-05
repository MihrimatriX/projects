from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone

from core.cache import APP_DIR, DB_PATH, ensure_db
from core.models import ScanNode


@dataclass
class ScanSnapshot:
    id: int
    root_path: str
    scanned_at: str
    total_size: int
    file_count: int


def _conn() -> sqlite3.Connection:
    ensure_db()
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            root_path TEXT NOT NULL,
            scanned_at TEXT NOT NULL,
            total_size INTEGER NOT NULL,
            file_count INTEGER NOT NULL,
            payload TEXT NOT NULL
        )
        """
    )
    return conn


def append_history(root: str, node: ScanNode) -> int:
    now = datetime.now(timezone.utc).isoformat()
    payload = json.dumps(node.to_dict(), ensure_ascii=False)
    with _conn() as conn:
        cur = conn.execute(
            """
            INSERT INTO scan_history (root_path, scanned_at, total_size, file_count, payload)
            VALUES (?, ?, ?, ?, ?)
            """,
            (root, now, node.size, node.file_count, payload),
        )
        snapshot_id = int(cur.lastrowid)
        rows = conn.execute(
            """
            SELECT id FROM scan_history
            WHERE root_path = ?
            ORDER BY id DESC
            """,
            (root,),
        ).fetchall()
        if len(rows) > 4:
            for (old_id,) in rows[4:]:
                conn.execute("DELETE FROM scan_history WHERE id = ?", (old_id,))
        conn.commit()
        return snapshot_id


def list_history(root: str, *, limit: int = 4) -> list[ScanSnapshot]:
    with _conn() as conn:
        rows = conn.execute(
            """
            SELECT id, root_path, scanned_at, total_size, file_count
            FROM scan_history
            WHERE root_path = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (root, limit),
        ).fetchall()
    return [
        ScanSnapshot(id=r[0], root_path=r[1], scanned_at=r[2], total_size=r[3], file_count=r[4])
        for r in rows
    ]


def load_snapshot(snapshot_id: int) -> ScanNode | None:
    with _conn() as conn:
        row = conn.execute(
            "SELECT payload FROM scan_history WHERE id = ?",
            (snapshot_id,),
        ).fetchone()
    if not row:
        return None
    return ScanNode.from_dict(json.loads(row[0]))
