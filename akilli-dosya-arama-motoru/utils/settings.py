from __future__ import annotations

import json
from pathlib import Path

from utils.config import DATA_DIR, DEFAULT_EXCLUDE_PATTERNS, DEFAULT_SEARCH_ROOT

_SETTINGS_DIR = DATA_DIR
_SETTINGS_FILE = _SETTINGS_DIR / "settings.json"


def _default_data() -> dict:
    root = DEFAULT_SEARCH_ROOT.expanduser()
    return {
        "search_roots": [str(root)] if root.exists() else [],
        "search_in_content": True,
        "show_snippets": True,
        "background_scan": True,
        "watcher_enabled": True,
        "fuzzy_search_enabled": True,
        "everything_bridge_enabled": False,
        "everything_filter_to_roots": True,
        "scheduled_reindex_enabled": False,
        "scheduled_reindex_hour": 3,
        "tantivy_primary": True,
        "exclude_patterns": list(DEFAULT_EXCLUDE_PATTERNS),
    }


def load_settings() -> dict:
    if not _SETTINGS_FILE.exists():
        return _default_data()
    try:
        data = json.loads(_SETTINGS_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _default_data()
    if not data.get("search_roots"):
        data["search_roots"] = _default_data()["search_roots"]
    data.setdefault("search_in_content", True)
    data.setdefault("show_snippets", True)
    data.setdefault("background_scan", True)
    data.setdefault("watcher_enabled", True)
    data.setdefault("fuzzy_search_enabled", True)
    data.setdefault("everything_bridge_enabled", False)
    data.setdefault("everything_filter_to_roots", True)
    data.setdefault("scheduled_reindex_enabled", False)
    data.setdefault("scheduled_reindex_hour", 3)
    data.setdefault("tantivy_primary", True)
    if not data.get("exclude_patterns"):
        data["exclude_patterns"] = list(DEFAULT_EXCLUDE_PATTERNS)
    return data


def save_settings(data: dict) -> None:
    _SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
    roots = [str(Path(p).expanduser()) for p in data.get("search_roots", []) if p]
    patterns = [
        line.strip()
        for line in data.get("exclude_patterns", [])
        if isinstance(line, str) and line.strip()
    ]
    if not patterns:
        patterns = list(DEFAULT_EXCLUDE_PATTERNS)
    payload = {
        "search_roots": roots,
        "search_in_content": bool(data.get("search_in_content", True)),
        "show_snippets": bool(data.get("show_snippets", True)),
        "background_scan": bool(data.get("background_scan", True)),
        "watcher_enabled": bool(data.get("watcher_enabled", True)),
        "fuzzy_search_enabled": bool(data.get("fuzzy_search_enabled", True)),
        "everything_bridge_enabled": bool(data.get("everything_bridge_enabled", False)),
        "everything_filter_to_roots": bool(data.get("everything_filter_to_roots", True)),
        "scheduled_reindex_enabled": bool(data.get("scheduled_reindex_enabled", False)),
        "scheduled_reindex_hour": int(data.get("scheduled_reindex_hour", 3)) % 24,
        "tantivy_primary": bool(data.get("tantivy_primary", True)),
        "exclude_patterns": patterns,
    }
    _SETTINGS_FILE.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def get_search_roots() -> list[Path]:
    roots = []
    for p in load_settings().get("search_roots", []):
        path = Path(p).expanduser()
        if path.is_dir():
            roots.append(path.resolve())
    if not roots:
        fallback = DEFAULT_SEARCH_ROOT.expanduser()
        if fallback.is_dir():
            roots.append(fallback.resolve())
    return roots


def content_search_enabled() -> bool:
    return bool(load_settings().get("search_in_content", True))


def snippets_enabled() -> bool:
    return bool(load_settings().get("show_snippets", True))


def background_scan_enabled() -> bool:
    return bool(load_settings().get("background_scan", True))


def get_exclude_patterns() -> list[str]:
    return list(load_settings().get("exclude_patterns", DEFAULT_EXCLUDE_PATTERNS))


def watcher_enabled() -> bool:
    return bool(load_settings().get("watcher_enabled", True))


def fuzzy_search_enabled() -> bool:
    return bool(load_settings().get("fuzzy_search_enabled", True))


def everything_bridge_enabled() -> bool:
    return bool(load_settings().get("everything_bridge_enabled", False))


def everything_filter_to_roots() -> bool:
    return bool(load_settings().get("everything_filter_to_roots", True))


def scheduled_reindex_enabled() -> bool:
    return bool(load_settings().get("scheduled_reindex_enabled", False))


def scheduled_reindex_hour() -> int:
    return int(load_settings().get("scheduled_reindex_hour", 3)) % 24


def tantivy_primary_enabled() -> bool:
    return bool(load_settings().get("tantivy_primary", True))
