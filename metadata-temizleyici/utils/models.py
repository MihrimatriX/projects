from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class MetadataTag:
    name: str
    label: str
    value: str
    risk: str


@dataclass(frozen=True)
class StripResult:
    source: Path
    output: Path
    backup: Path | None
    tags_removed: int
    removed_tag_names: tuple[str, ...]
    overwritten: bool
    engine: str
    hash_changed: bool = False
    dry_run: bool = False
    before_tags: tuple[MetadataTag, ...] = ()
    after_tags: tuple[MetadataTag, ...] = ()
