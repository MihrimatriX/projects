"""Yerel arama geçmişi — gizlilik dostu, cihazda kalır (Faz 3)."""

from __future__ import annotations

import json
import time

from utils.config import DATA_DIR

_HISTORY_FILE = DATA_DIR / "search_history.json"
_MAX_ENTRIES = 200


def _load() -> list[dict]:
    if not _HISTORY_FILE.exists():
        return []
    try:
        data = json.loads(_HISTORY_FILE.read_text(encoding="utf-8"))
        if isinstance(data, list):
            return data
    except (json.JSONDecodeError, OSError):
        pass
    return []


def _save(entries: list[dict]) -> None:
    _HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    _HISTORY_FILE.write_text(
        json.dumps(entries[:_MAX_ENTRIES], indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def record_search(query: str, result_count: int, elapsed_ms: int) -> None:
    q = query.strip()
    if len(q) < 2:
        return
    entries = _load()
    entries = [e for e in entries if e.get("query") != q]
    entries.insert(
        0,
        {
            "query": q,
            "results": result_count,
            "ms": elapsed_ms,
            "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        },
    )
    _save(entries)


def recent_queries(limit: int = 8) -> list[str]:
    entries = _load()
    out: list[str] = []
    for item in entries:
        q = item.get("query", "")
        if q and q not in out:
            out.append(q)
        if len(out) >= limit:
            break
    return out


def history_stats() -> dict:
    entries = _load()
    if not entries:
        return {"total": 0, "top_queries": []}
    top = sorted(entries, key=lambda e: e.get("results", 0), reverse=True)[:5]
    return {
        "total": len(entries),
        "top_queries": [(e.get("query", ""), e.get("results", 0)) for e in top],
    }


def clear_history() -> None:
    if _HISTORY_FILE.exists():
        _HISTORY_FILE.unlink()
