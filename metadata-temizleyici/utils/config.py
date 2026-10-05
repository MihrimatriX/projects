from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

APP_VERSION = "0.4.1"
SETTINGS_FILE = Path.home() / ".metadata-temizleyici" / "settings.json"


@dataclass
class AppSettings:
    backup_enabled: bool = True
    overwrite_in_place: bool = True
    last_directory: str = ""
    last_preset_id: str = "social_media"
    watch_enabled: bool = False
    watch_directory: str = ""
    auto_export_audit: bool = False
    audit_directory: str = ""

    def save(self) -> None:
        SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text(json.dumps(asdict(self), ensure_ascii=False, indent=2), encoding="utf-8")

    @classmethod
    def load(cls) -> AppSettings:
        if not SETTINGS_FILE.exists():
            return cls()
        try:
            data = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
            return cls(
                backup_enabled=bool(data.get("backup_enabled", True)),
                overwrite_in_place=bool(data.get("overwrite_in_place", True)),
                last_directory=str(data.get("last_directory", "")),
                last_preset_id=str(data.get("last_preset_id", "social_media")),
                watch_enabled=bool(data.get("watch_enabled", False)),
                watch_directory=str(data.get("watch_directory", "")),
                auto_export_audit=bool(data.get("auto_export_audit", False)),
                audit_directory=str(data.get("audit_directory", "")),
            )
        except (json.JSONDecodeError, OSError):
            return cls()
