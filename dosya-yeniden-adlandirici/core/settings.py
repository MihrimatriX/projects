from __future__ import annotations

import json
from copy import deepcopy
from dataclasses import asdict, dataclass, field
from pathlib import Path

from core.app_info import APP_ID
from core.models import CaseMode, ExifNamingMode, Rule, RuleType


@dataclass
class AppSettings:
    last_folder: str = ""
    recursive: bool = False
    window_width: int = 960
    window_height: int = 640
    last_rules: list[dict] = field(default_factory=list)
    macro_rules: list[dict] = field(default_factory=list)
    filter_changed_only: bool = False
    include_hidden: bool = False
    undo_stack_max: int = 20
    exif_mtime_fallback_default: bool = True
    preview_async_threshold: int = 80
    theme: str = "dark"
    show_welcome: bool = True


def data_dir() -> Path:
    return Path.home() / ".local" / "share" / APP_ID


class SettingsStore:
    _instance: SettingsStore | None = None

    def __init__(self) -> None:
        base = data_dir()
        base.mkdir(parents=True, exist_ok=True)
        self._path = base / "settings.json"
        self.settings = self._load()

    @classmethod
    def instance(cls) -> SettingsStore:
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _load(self) -> AppSettings:
        if not self._path.exists():
            return AppSettings()
        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
            fields = AppSettings.__dataclass_fields__
            kwargs = {k: data[k] for k in fields if k in data}
            return AppSettings(**kwargs)
        except (OSError, ValueError, TypeError, KeyError, AttributeError):
            return AppSettings()

    def save(self) -> None:
        self._path.write_text(
            json.dumps(asdict(self.settings), indent=2, ensure_ascii=False),
            encoding="utf-8",
        )


def rule_to_dict(rule: Rule) -> dict:
    d = asdict(rule)
    d["rule_type"] = rule.rule_type.value
    d["case_mode"] = rule.case_mode.value
    d["exif_naming_mode"] = rule.exif_naming_mode.value
    return d


def rule_from_dict(data: dict) -> Rule:
    return Rule(
        enabled=data.get("enabled", True),
        rule_type=RuleType(data.get("rule_type", RuleType.FIND_REPLACE.value)),
        pattern=data.get("pattern", ""),
        replacement=data.get("replacement", ""),
        use_regex=data.get("use_regex", False),
        ignore_case=data.get("ignore_case", True),
        number_position=data.get("number_position", "prefix"),
        start=int(data.get("start", 1)),
        pad=int(data.get("pad", 3)),
        separator=data.get("separator", "_"),
        case_mode=CaseMode(data.get("case_mode", CaseMode.LOWER.value)),
        old_ext=data.get("old_ext", ""),
        new_ext=data.get("new_ext", ""),
        condition_ext=data.get("condition_ext", ""),
        exif_format=data.get("exif_format", "%Y%m%d_%H%M%S"),
        keep_original_ext=data.get("keep_original_ext", True),
        exif_use_mtime_fallback=data.get("exif_use_mtime_fallback", True),
        exif_naming_mode=ExifNamingMode(
            data.get("exif_naming_mode", ExifNamingMode.EXIF_OR_MTIME.value)
        ),
        mtime_format=data.get("mtime_format", "%Y%m%d"),
        exif_mtime_separator=data.get("exif_mtime_separator", "_"),
    )


def rules_to_list(rules: list[Rule]) -> list[dict]:
    return [rule_to_dict(deepcopy(r)) for r in rules]


def rules_from_list(data: list[dict]) -> list[Rule]:
    return [rule_from_dict(item) for item in data]
