from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path

_CONFIG_DIR = Path.home() / ".kodsuz-web-kaziyici"
_CONFIG_FILE = _CONFIG_DIR / "settings.json"

DEFAULT_SETTINGS: dict = {
    "rate": 2.0,
    "default_mode": "table",
    "encoding": "utf-8",
    "export_path": "",
    "save_history": True,
    "delay_ms": 2000,
    "timeout_s": 30,
    "max_rows": 500,
    "user_agent": "chrome",
    "custom_user_agent": "",
    "strip_html": True,
    "follow_pagination": False,
    "robots_check": True,
    "fetch_engine": "browser",
    "render_wait_ms": 1500,
    "auto_scroll": True,
    "accept_language": "tr-TR,tr;q=0.9,en;q=0.8",
}

USER_AGENTS = {
    "chrome": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "firefox": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
    "bot": "ScraperBot/1.0 (+https://local; ethical)",
}


def _default_config() -> dict:
    return {
        "robots_dismissed": False,
        "settings": deepcopy(DEFAULT_SETTINGS),
        "history": [],
    }


def load_config() -> dict:
    if not _CONFIG_FILE.exists():
        return _default_config()
    try:
        data = json.loads(_CONFIG_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _default_config()
    base = _default_config()
    base.update({k: v for k, v in data.items() if k in ("robots_dismissed", "history")})
    base["settings"] = {**DEFAULT_SETTINGS, **data.get("settings", {})}
    return base


def save_config(data: dict) -> None:
    _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    # Önce geçici dosyaya yaz, sonra değiştir: yazma yarıda kesilirse ayarlar/geçmiş bozulmasın
    tmp = _CONFIG_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, _CONFIG_FILE)


def get_settings() -> dict:
    return load_config()["settings"]


def update_settings(patch: dict) -> dict:
    data = load_config()
    data["settings"] = {**data["settings"], **patch}
    save_config(data)
    return data["settings"]


def robots_dismissed() -> bool:
    return bool(load_config().get("robots_dismissed", False))


def dismiss_robots_banner() -> None:
    data = load_config()
    data["robots_dismissed"] = True
    save_config(data)


def get_history() -> list[dict]:
    return list(load_config().get("history", []))


def push_history(entry: dict) -> None:
    data = load_config()
    if not data["settings"].get("save_history", True):
        return
    history = data.get("history", [])
    history.insert(0, entry)
    data["history"] = history[:20]
    save_config(data)


def resolve_user_agent(settings: dict) -> str:
    key = settings.get("user_agent", "chrome")
    if key == "custom":
        return settings.get("custom_user_agent") or USER_AGENTS["chrome"]
    return USER_AGENTS.get(key, USER_AGENTS["chrome"])
