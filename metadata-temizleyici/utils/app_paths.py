from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def asset_path(name: str) -> Path:
    if getattr(sys, "frozen", False):
        base = Path(getattr(sys, "_MEIPASS", ROOT))
        return base / "assets" / name
    return ROOT / "assets" / name
