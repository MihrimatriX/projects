from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

from core.cache import APP_DIR

SETTINGS_PATH = APP_DIR / "settings.json"
MAX_RECENT_ROOTS = 8


@dataclass
class AppSettings:
    first_run_completed: bool = False
    last_scan_root: str = "C:\\"
    depth_index: int = 1
    view_index: int = 0
    window_width: int = 1280
    window_height: int = 760
    scheduled_scan_enabled: bool = False
    scheduled_scan_days: int = 7
    scheduled_scan_root: str = "C:\\Users"
    last_scheduled_scan_utc: str = ""
    show_duplicates_panel: bool = True
    min_duplicate_size_mb: int = 10
    recent_roots: list[str] = field(default_factory=list)

    def remember_root(self, root: str) -> None:
        """Son taranan klasörü listenin başına alır (büyük/küçük harf duyarsız tekil)."""
        key = root.rstrip("\\/").casefold()
        rest = [r for r in self.recent_roots if r.rstrip("\\/").casefold() != key]
        self.recent_roots = [root, *rest][:MAX_RECENT_ROOTS]


class SettingsStore:
    _instance: SettingsStore | None = None

    def __init__(self) -> None:
        APP_DIR.mkdir(parents=True, exist_ok=True)
        self.settings = self._load()

    @classmethod
    def instance(cls) -> SettingsStore:
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _load(self) -> AppSettings:
        if not SETTINGS_PATH.exists():
            return AppSettings()
        try:
            data = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
            return AppSettings(**{k: v for k, v in data.items() if k in AppSettings.__dataclass_fields__})
        except (OSError, ValueError, TypeError, AttributeError):
            # Bozuk/okunamayan ayar dosyası açılışı engellemesin.
            return AppSettings()

    def save(self) -> None:
        SETTINGS_PATH.write_text(
            json.dumps(asdict(self.settings), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
