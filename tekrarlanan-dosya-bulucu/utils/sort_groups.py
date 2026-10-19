from __future__ import annotations

from enum import Enum

from utils.models import DuplicateGroup


class SortMode(str, Enum):
    WASTED = "wasted"
    COUNT = "count"
    SIZE = "size"
    PATH = "path"


def sort_groups(groups: list[DuplicateGroup], mode: SortMode) -> list[DuplicateGroup]:
    if mode == SortMode.COUNT:
        return sorted(groups, key=lambda g: g.count, reverse=True)
    if mode == SortMode.SIZE:
        return sorted(groups, key=lambda g: g.size, reverse=True)
    if mode == SortMode.PATH:
        return sorted(
            groups,
            key=lambda g: min((f.path.lower() for f in g.files), default=""),
        )
    return sorted(groups, key=lambda g: g.wasted_bytes, reverse=True)
