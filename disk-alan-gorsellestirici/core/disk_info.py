from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path


@dataclass
class DiskStats:
    path: str
    total: int
    used: int
    free: int

    @property
    def used_percent(self) -> float:
        return (self.used / self.total * 100) if self.total else 0.0


def get_disk_stats(path: str) -> DiskStats:
    root = Path(path).drive or path
    if not root.endswith("\\"):
        root = f"{root}\\"
    usage = shutil.disk_usage(root)
    return DiskStats(path=root, total=usage.total, used=usage.used, free=usage.free)
