from __future__ import annotations

import json
from datetime import datetime, timezone

from utils.formatters import human_size
from utils.settings import APP_DIR

HISTORY_PATH = APP_DIR / "scan_history.json"
MAX_ENTRIES = 30


def append_scan_entry(
    *,
    scan_type: str,
    roots: list[str],
    group_count: int,
    wasted_bytes: int,
    from_cache: bool = False,
) -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    entries = load_history()
    entries.insert(
        0,
        {
            "at": datetime.now(timezone.utc).isoformat(),
            "scan_type": scan_type,
            "roots": roots,
            "group_count": group_count,
            "wasted_bytes": wasted_bytes,
            "wasted_human": human_size(wasted_bytes),
            "from_cache": from_cache,
        },
    )
    HISTORY_PATH.write_text(
        json.dumps(entries[:MAX_ENTRIES], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_history() -> list[dict]:
    if not HISTORY_PATH.exists():
        return []
    try:
        data = json.loads(HISTORY_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []
