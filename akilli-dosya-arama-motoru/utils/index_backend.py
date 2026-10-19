"""İndeks backend soyutlaması — Tantivy arama + FTS5 canlı delta (Windows uyumlu)."""

from __future__ import annotations

from typing import Protocol

DeltaEvent = tuple


class IndexBackend(Protocol):
    def is_ready(self) -> bool: ...
    def search_names(self, query: str, *, limit: int = 50) -> list[tuple[str, str]]: ...


def tantivy_available() -> bool:
    try:
        import tantivy  # noqa: F401

        return True
    except ImportError:
        return False


def use_tantivy_primary() -> bool:
    from utils.settings import tantivy_primary_enabled

    return tantivy_primary_enabled() and tantivy_available()


def active_backend_name() -> str:
    return "tantivy" if use_tantivy_primary() else "fts5"


def _merge_hits(
    *layers: list[tuple[str, str]],
    limit: int,
) -> list[tuple[str, str]]:
    seen: set[str] = set()
    merged: list[tuple[str, str]] = []
    for layer in layers:
        for name, path in layer:
            if path in seen:
                continue
            seen.add(path)
            merged.append((name, path))
            if len(merged) >= limit:
                return merged
    return merged


def index_ready() -> bool:
    from utils import index_db

    if use_tantivy_primary():
        from utils import tantivy_index

        return index_db.index_ready() or tantivy_index.index_ready()
    return index_db.index_ready()


def get_index_stats() -> dict:
    from utils import index_db

    fts = index_db.get_index_stats()
    if not use_tantivy_primary():
        return fts

    from utils import tantivy_index

    tav = tantivy_index.get_index_stats()
    return {
        "count": max(int(fts.get("count", 0)), int(tav.get("count", 0))),
        "built_at": fts.get("built_at") or tav.get("built_at"),
        "fts5_count": fts.get("count", 0),
        "tantivy_count": tav.get("count", 0),
    }


def build_index(*args, **kwargs) -> int:
    # Tam indeks: önce FTS5 (SQLite) her zaman kurulur; Tantivy açıksa ardından o da
    # sıfırdan kurulur. Canlı değişiklikler (watcher) yalnızca FTS5'e yazılır, aramada
    # iki katman search_index() içinde birleştirilir.
    from utils import index_db

    if use_tantivy_primary():
        from utils import tantivy_index

        fts_count = index_db.build_index(*args, **kwargs)
        try:
            return tantivy_index.build_index(*args, **kwargs)
        except Exception:
            return fts_count

    return index_db.build_index(*args, **kwargs)


def search_index(*args, **kwargs) -> list[tuple[str, str]]:
    from utils import index_db

    limit = kwargs.get("limit", 50)
    if not use_tantivy_primary():
        return index_db.search_index(*args, **kwargs)

    from utils import tantivy_index

    tav_hits: list[tuple[str, str]] = []
    if tantivy_index.index_ready():
        try:
            tav_hits = tantivy_index.search_index(*args, **kwargs)
        except Exception:
            tav_hits = []

    fts_hits: list[tuple[str, str]] = []
    if index_db.index_ready():
        fts_hits = index_db.search_index(*args, **kwargs)

    if tav_hits or fts_hits:
        return _merge_hits(tav_hits, fts_hits, limit=limit)
    return []


def list_index_candidates(*args, **kwargs) -> list[tuple[str, str]]:
    from utils import index_db

    max_rows = kwargs.get("max_rows", 10000)
    if not use_tantivy_primary():
        return index_db.list_index_candidates(*args, **kwargs)

    from utils import tantivy_index

    tav: list[tuple[str, str]] = []
    if tantivy_index.index_ready():
        try:
            tav = tantivy_index.list_index_candidates(*args, **kwargs)
        except Exception:
            tav = []

    fts: list[tuple[str, str]] = []
    if index_db.index_ready():
        fts = index_db.list_index_candidates(*args, **kwargs)

    return _merge_hits(tav, fts, limit=max_rows)


def apply_delta_batch(events: list[DeltaEvent]) -> int:
    """Canlı FS watcher güncellemeleri — her zaman FTS5 (Tantivy delta Windows'ta kararsız)."""
    from utils import index_db

    return index_db.apply_delta_batch(events)


def export_index(dest):
    if use_tantivy_primary():
        from utils import tantivy_index

        return tantivy_index.export_index(dest)
    from utils import index_db

    return index_db.export_index(dest)


def import_index(src) -> None:
    if use_tantivy_primary():
        from utils import tantivy_index

        tantivy_index.import_index(src)
        return  # Tantivy yedeği (zip/klasör) FTS5 .db dosyasının üzerine kopyalanmamalı
    from utils import index_db

    index_db.import_index(src)


def remove_file(path) -> None:
    from utils import index_db

    index_db.remove_file(path)


def remove_tree(dir_path) -> None:
    from utils import index_db

    index_db.remove_tree(dir_path)


def index_file(path) -> bool:
    from utils import index_db

    return index_db.index_file(path)


def backend_status() -> dict:
    from utils import index_db

    active = active_backend_name()
    fts_ready = index_db.index_ready()
    tav = tantivy_available()
    tav_ready = False
    if tav and use_tantivy_primary():
        from utils import tantivy_index

        tav_ready = tantivy_index.index_ready()

    if active == "tantivy":
        note = (
            "Tantivy arama + FTS5 canlı delta. "
            "Dosya değişiklikleri FTS5'e yazılır; tam hız için ara sıra yeniden indeksleyin."
        )
        if not tav:
            note = "Tantivy paketi yüklü değil — FTS5 kullanılıyor. pip install tantivy"
    else:
        note = "FTS5 birincil backend."
        if tav:
            note += " Ayarlardan Tantivy birincil yapılabilir."

    return {
        "active": active,
        "fts5": fts_ready,
        "tantivy": tav,
        "tantivy_ready": tav_ready,
        "tantivy_note": note,
    }
