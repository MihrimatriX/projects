from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class KeepStrategy(str, Enum):
    OLDEST = "oldest"
    NEWEST = "newest"
    SHORTEST_PATH = "shortest"


@dataclass
class DuplicateFile:
    path: str
    size: int
    mtime: float
    inode: int = 0
    device: int = 0
    marked_for_delete: bool = False
    is_keeper: bool = False
    preview: str | None = None


@dataclass
class DuplicateGroup:
    hash_hex: str
    size: int
    files: list[DuplicateFile] = field(default_factory=list)
    is_hardlink_group: bool = False

    @property
    def count(self) -> int:
        return len(self.files)

    @property
    def wasted_bytes(self) -> int:
        if self.is_hardlink_group:
            return 0
        return self.size * max(0, self.count - 1)

    @property
    def hash_short(self) -> str:
        return f"{self.hash_hex[:8]}…{self.hash_hex[-4:]}"


@dataclass
class ScanSettings:
    roots: list[str] = field(default_factory=list)
    min_size_bytes: int = 1024
    exclude_extensions: list[str] = field(
        default_factory=lambda: [".tmp", ".log", ".cache"]
    )
    skip_hidden: bool = True
    skip_system_dirs: bool = True
    follow_symlinks: bool = False
    hash_workers: int = 4


@dataclass
class ScanProgress:
    phase: str
    files_scanned: int
    current_path: str
    groups_found: int
    bytes_hashed: int = 0
