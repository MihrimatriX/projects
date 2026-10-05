from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path

from utils.app_info import APP_ID


def _app_dir() -> Path:
    # Testler/taşınabilir kullanım için tüm veri klasörü değiştirilebilir.
    # Varsayılan yol disk-alan-gorsellestirici köprüsüyle (tekrarlanan_bridge.py) aynı kalmalı.
    override = os.environ.get("TEKRARLANAN_DATA_DIR")
    if override:
        return Path(override)
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return Path(base) / APP_ID


APP_DIR = _app_dir()
SETTINGS_PATH = APP_DIR / "settings.json"


@dataclass
class AppSettings:
    roots: list[str] = field(default_factory=list)
    min_size_kb: int = 1
    exclude_extensions: str = ".tmp,.log,.cache"
    skip_hidden: bool = True
    skip_system_dirs: bool = True
    keep_strategy: str = "oldest"
    use_scan_cache: bool = True
    hash_workers: int = 4
    first_run_completed: bool = True
    window_width: int = 960
    window_height: int = 720
    last_export_dir: str = ""
    results_page_size: int = 80
    scheduled_scan_enabled: bool = False
    scheduled_scan_days: int = 7
    last_scheduled_scan_utc: str = ""
    minimize_to_tray: bool = False
    follow_symlinks: bool = False
    compact_list_threshold: int = 120
    sort_mode: str = "wasted"
    protected_folders: str = ""  # ';' ile ayrılır; bu klasörlerdeki kopyalar asla silinmeye işaretlenmez


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
            fields = AppSettings.__dataclass_fields__
            return AppSettings(**{k: v for k, v in data.items() if k in fields})
        except (ValueError, TypeError, AttributeError, OSError):
            # Bozuk/okunamayan settings.json (ör. yarım yazılmış, liste kökü) varsayılanlara döner
            return AppSettings()

    def save(self) -> None:
        SETTINGS_PATH.write_text(
            json.dumps(asdict(self.settings), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
