from __future__ import annotations

import os
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


def path_key(path: Path) -> str:
    """Dosya sistemi kimliği: Windows'ta büyük/küçük harf duyarsız tam yol."""
    return os.path.normcase(os.path.abspath(path))


class RuleType(str, Enum):
    FIND_REPLACE = "find_replace"
    NUMBERING = "numbering"
    CASE = "case"
    EXTENSION = "extension"
    EXIF_DATE = "exif_date"


class CaseMode(str, Enum):
    LOWER = "lower"
    UPPER = "upper"
    TITLE = "title"
    CAPITALIZE = "capitalize"


class ExifNamingMode(str, Enum):
    EXIF_OR_MTIME = "exif_or_mtime"
    EXIF_ONLY = "exif_only"
    MTIME_ONLY = "mtime_only"
    EXIF_AND_MTIME = "exif_and_mtime"


class PreviewStatus(str, Enum):
    OK = "ok"
    UNCHANGED = "unchanged"
    CONFLICT = "conflict"
    ERROR = "error"
    RESERVED = "reserved"
    SKIPPED = "skipped"


@dataclass
class Rule:
    enabled: bool = True
    rule_type: RuleType = RuleType.FIND_REPLACE
    pattern: str = ""
    replacement: str = ""
    use_regex: bool = False
    ignore_case: bool = True
    number_position: str = "prefix"
    start: int = 1
    pad: int = 3
    separator: str = "_"
    case_mode: CaseMode = CaseMode.LOWER
    old_ext: str = ""
    new_ext: str = ""
    condition_ext: str = ""
    exif_format: str = "%Y%m%d_%H%M%S"
    keep_original_ext: bool = True
    exif_use_mtime_fallback: bool = True
    exif_naming_mode: ExifNamingMode = ExifNamingMode.EXIF_OR_MTIME
    mtime_format: str = "%Y%m%d"
    exif_mtime_separator: str = "_"

    def label(self) -> str:
        labels = {
            RuleType.FIND_REPLACE: "Bul / Değiştir",
            RuleType.NUMBERING: "Numaralandır",
            RuleType.CASE: "Büyük / küçük harf",
            RuleType.EXTENSION: "Uzantı değiştir",
            RuleType.EXIF_DATE: "EXIF tarih",
        }
        base = labels[self.rule_type]
        if self.condition_ext.strip():
            return f"{base} (ext:{self.condition_ext})"
        return base


@dataclass
class PreviewRow:
    path: Path
    original_name: str
    new_name: str
    status: PreviewStatus = PreviewStatus.OK
    message: str = ""

    @property
    def changed(self) -> bool:
        return self.original_name != self.new_name and self.status not in (
            PreviewStatus.ERROR,
            PreviewStatus.CONFLICT,
            PreviewStatus.RESERVED,
        )


@dataclass
class UndoRecord:
    moves: list[tuple[Path, Path]] = field(default_factory=list)
