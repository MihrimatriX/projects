"""Hariç tutma desenleri — ayarlardan + varsayılanlar."""

from __future__ import annotations

import fnmatch
from pathlib import Path

from utils.config import EXCLUDE_DIR_NAMES
from utils.settings import get_exclude_patterns


def should_skip_dir(name: str, extra_patterns: list[str] | None = None) -> bool:
    if name in EXCLUDE_DIR_NAMES:
        return True
    if name.startswith("."):
        return True
    patterns = extra_patterns if extra_patterns is not None else get_exclude_patterns()
    return any(fnmatch.fnmatch(name, pat) for pat in patterns)


def should_skip_file(path: Path, extra_patterns: list[str] | None = None) -> bool:
    patterns = extra_patterns if extra_patterns is not None else get_exclude_patterns()
    name = path.name
    return any(fnmatch.fnmatch(name, pat) for pat in patterns)
