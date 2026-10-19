from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

_DB_DIR = Path.home() / ".yerel-sesli-metin-dokumu"
_DB_PATH = _DB_DIR / "history.db"
_MAX_JOBS = 50


def _connect() -> sqlite3.Connection:
    _DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(_DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_name TEXT NOT NULL,
            file_path TEXT,
            duration_sec REAL,
            created_at TEXT NOT NULL
        )
        """
    )
    return conn


def add_job(file_path: str, duration_sec: float) -> int:
    name = Path(file_path).name
    ts = datetime.now(timezone.utc).isoformat()
    with _connect() as conn:
        cur = conn.execute(
            "INSERT INTO jobs (file_name, file_path, duration_sec, created_at) VALUES (?, ?, ?, ?)",
            (name, file_path, duration_sec, ts),
        )
        conn.execute(
            f"""
            DELETE FROM jobs WHERE id NOT IN (
                SELECT id FROM jobs ORDER BY id DESC LIMIT {_MAX_JOBS}
            )
            """
        )
        conn.commit()
        return int(cur.lastrowid)


def list_jobs(limit: int = 50) -> list[dict]:
    with _connect() as conn:
        rows = conn.execute(
            """
            SELECT id, file_name, file_path, duration_sec, created_at
            FROM jobs ORDER BY id DESC LIMIT ?
            """,
            (limit,),
        ).fetchall()
    return [dict(r) for r in rows]


def delete_job(job_id: int) -> bool:
    with _connect() as conn:
        cur = conn.execute("DELETE FROM jobs WHERE id = ?", (job_id,))
        conn.commit()
        return cur.rowcount > 0
