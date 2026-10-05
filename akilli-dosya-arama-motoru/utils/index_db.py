from __future__ import annotations

import hashlib
import os
import sqlite3
import time
from pathlib import Path

from utils.excludes import should_skip_dir, should_skip_file
from utils.config import DATA_DIR
from utils.settings import get_search_roots

_DB_DIR = DATA_DIR
_DB_PATH = _DB_DIR / "fts_index.db"

DeltaEvent = tuple  # ('add'|'del'|'del_tree'|'move', path, ...)


def _connect() -> sqlite3.Connection:
    _DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(_DB_PATH))
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


# Veri ~/.akilli-dosya-arama/fts_index.db içinde: yalnızca dosya adı (FTS5, unicode61)
# indekslenir, tam yol saklanır. Sorgu "kelime"* önek eşleşmesine çevrilir.
def _init_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE VIRTUAL TABLE IF NOT EXISTS file_fts USING fts5(
            name,
            path UNINDEXED,
            tokenize='unicode61'
        )
        """
    )


def _roots_signature(roots: list[Path]) -> str:
    joined = "|".join(sorted(str(r.resolve()) for r in roots))
    return hashlib.sha256(joined.encode()).hexdigest()[:16]


def _normalize_path(path: Path | str) -> str:
    return str(Path(path).expanduser().resolve())


def index_ready() -> bool:
    if not _DB_PATH.exists():
        return False
    try:
        with _connect() as conn:
            _init_schema(conn)
            row = conn.execute("SELECT COUNT(*) FROM file_fts").fetchone()
            return bool(row and row[0] > 0)
    except sqlite3.Error:
        return False


def get_index_stats() -> dict:
    if not _DB_PATH.exists():
        return {"count": 0, "built_at": None}
    with _connect() as conn:
        _init_schema(conn)
        count = conn.execute("SELECT COUNT(*) FROM file_fts").fetchone()[0]
        built = conn.execute("SELECT value FROM meta WHERE key='built_at'").fetchone()
    return {"count": count, "built_at": built[0] if built else None}


def _should_skip_dir(name: str) -> bool:
    return should_skip_dir(name)


def _index_file_conn(conn: sqlite3.Connection, path: Path) -> bool:
    if not path.is_file():
        return False
    if should_skip_file(path):
        return False
    try:
        key = _normalize_path(path)
    except OSError:
        return False
    conn.execute("DELETE FROM file_fts WHERE path = ?", (key,))
    conn.execute(
        "INSERT INTO file_fts (name, path) VALUES (?, ?)",
        (path.name, key),
    )
    return True


def remove_file(path: Path | str) -> None:
    key = _normalize_path(path)
    with _connect() as conn:
        _init_schema(conn)
        conn.execute("DELETE FROM file_fts WHERE path = ?", (key,))
        conn.commit()


def remove_tree(dir_path: Path | str) -> None:
    root = _normalize_path(dir_path)
    prefix = root.rstrip(os.sep) + os.sep
    with _connect() as conn:
        _init_schema(conn)
        conn.execute("DELETE FROM file_fts WHERE path = ? OR path LIKE ?", (root, prefix + "%"))
        conn.commit()


def index_file(path: Path | str) -> bool:
    p = Path(path)
    with _connect() as conn:
        _init_schema(conn)
        ok = _index_file_conn(conn, p)
        if ok:
            conn.execute(
                "INSERT INTO meta (key, value) VALUES ('built_at', ?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (time.strftime("%Y-%m-%dT%H:%M:%S"),),
            )
        conn.commit()
    return ok


def apply_delta_batch(events: list[DeltaEvent]) -> int:
    """Watchdog olaylarını toplu uygular; güncel dosya sayısını döner."""
    if not events:
        return get_index_stats()["count"]

    with _connect() as conn:
        _init_schema(conn)
        changed = False
        for ev in events:
            kind = ev[0]
            if kind == "add":
                changed = _index_file_conn(conn, Path(ev[1])) or changed
            elif kind == "del":
                try:
                    conn.execute("DELETE FROM file_fts WHERE path = ?", (_normalize_path(ev[1]),))
                    changed = True
                except OSError:
                    continue
            elif kind == "del_tree":
                root = _normalize_path(ev[1])
                prefix = root.rstrip(os.sep) + os.sep
                conn.execute(
                    "DELETE FROM file_fts WHERE path = ? OR path LIKE ?",
                    (root, prefix + "%"),
                )
                changed = True
            elif kind == "move":
                try:
                    conn.execute("DELETE FROM file_fts WHERE path = ?", (_normalize_path(ev[1]),))
                except OSError:
                    pass
                changed = _index_file_conn(conn, Path(ev[2])) or changed

        if changed:
            conn.execute(
                "INSERT INTO meta (key, value) VALUES ('built_at', ?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (time.strftime("%Y-%m-%dT%H:%M:%S"),),
            )
        conn.commit()

    return get_index_stats()["count"]


def list_index_candidates(query: str, *, max_rows: int = 10000) -> list[tuple[str, str]]:
    """Fuzzy arama için aday dosya listesi (name, path)."""
    if not index_ready():
        return []

    q = query.strip().lower()
    with _connect() as conn:
        _init_schema(conn)
        if len(q) >= 2:
            rows = conn.execute(
                "SELECT name, path FROM file_fts WHERE lower(name) LIKE ? LIMIT ?",
                (f"{q[:2]}%", max_rows),
            ).fetchall()
            if len(rows) < max(20, max_rows // 4):
                rows = conn.execute(
                    "SELECT name, path FROM file_fts WHERE lower(name) LIKE ? LIMIT ?",
                    (f"{q[0]}%", max_rows),
                ).fetchall()
        elif len(q) == 1:
            rows = conn.execute(
                "SELECT name, path FROM file_fts WHERE lower(name) LIKE ? LIMIT ?",
                (f"{q}%", max_rows),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT name, path FROM file_fts LIMIT ?",
                (max_rows,),
            ).fetchall()
    return [(r[0], r[1]) for r in rows]


def export_index(dest: Path) -> Path:
    """FTS5 veritabanını yedekler."""
    import shutil

    if not _DB_PATH.exists():
        raise FileNotFoundError("İndeks dosyası yok — önce yeniden indeksleyin.")
    dest = dest.expanduser().resolve()
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(_DB_PATH, dest)
    return dest


def import_index(src: Path) -> None:
    """Yedekten FTS5 veritabanını geri yükler."""
    import shutil

    src = src.expanduser().resolve()
    if not src.is_file():
        raise FileNotFoundError(f"Yedek bulunamadı: {src}")
    _DB_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, _DB_PATH)


def build_index(
    roots: list[Path] | None = None,
    *,
    on_progress=None,
    cancel_check=None,
) -> int:
    root_list = list(roots) if roots else get_search_roots()
    root_list = [r.resolve() for r in root_list if r.exists()]
    if not root_list:
        raise FileNotFoundError("İndeks için en az bir geçerli klasör gerekli.")

    total_added = 0
    with _connect() as conn:
        _init_schema(conn)
        conn.execute("DELETE FROM file_fts")
        conn.execute("DELETE FROM meta")

        batch: list[tuple[str, str]] = []
        scanned = 0

        for root_path in root_list:
            if cancel_check and cancel_check():
                break
            for dirpath, dirnames, filenames in os.walk(root_path):
                if cancel_check and cancel_check():
                    break
                dirnames[:] = [d for d in dirnames if not _should_skip_dir(d)]
                for name in filenames:
                    if cancel_check and cancel_check():
                        break
                    path = Path(dirpath) / name
                    if should_skip_file(path):
                        continue
                    try:
                        key = str(path.resolve())
                    except OSError:
                        continue
                    batch.append((name, key))
                    scanned += 1
                    if len(batch) >= 500:
                        conn.executemany(
                            "INSERT INTO file_fts (name, path) VALUES (?, ?)", batch
                        )
                        total_added += len(batch)
                        batch.clear()
                    if on_progress and scanned % 200 == 0:
                        on_progress(scanned)
                if cancel_check and cancel_check():
                    break

        if batch:
            conn.executemany("INSERT INTO file_fts (name, path) VALUES (?, ?)", batch)
            total_added += len(batch)

        conn.execute(
            "INSERT INTO meta (key, value) VALUES ('built_at', ?)",
            (time.strftime("%Y-%m-%dT%H:%M:%S"),),
        )
        conn.execute(
            "INSERT INTO meta (key, value) VALUES ('roots_sig', ?)",
            (_roots_signature(root_list),),
        )
        conn.commit()

    return total_added


def search_index(
    query: str,
    *,
    extension: str | None = None,
    limit: int = 50,
) -> list[tuple[str, str]]:
    """FTS5 ile dosya adı araması; (name, path) listesi döner."""
    if not index_ready():
        return []

    needle = query.strip()
    if not needle and not extension:
        return []

    # Tırnaklar FTS5'te ikilenerek kaçırılır. Metinsiz "ext:py" sorgusunda MATCH
    # kullanılamaz ("*" geçersiz sözdizimi) — yalnızca uzantı LIKE ile süzülür.
    fts_query = " ".join('"' + tok.replace('"', '""') + '"*' for tok in needle.split())
    if fts_query:
        sql = "SELECT name, path FROM file_fts WHERE file_fts MATCH ?"
        params: list = [fts_query]
    else:
        sql = "SELECT name, path FROM file_fts WHERE 1"
        params = []

    if extension:
        sql += " AND name LIKE ?"
        params.append(f"%.{extension}")

    sql += " LIMIT ?"
    params.append(limit)

    try:
        with _connect() as conn:
            _init_schema(conn)
            rows = conn.execute(sql, params).fetchall()
        return [(r[0], r[1]) for r in rows]
    except sqlite3.OperationalError:
        return []
