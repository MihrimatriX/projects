from __future__ import annotations

from utils.models import DuplicateGroup


def filter_groups(groups: list[DuplicateGroup], query: str) -> list[DuplicateGroup]:
    q = query.strip().lower()
    if not q:
        return groups
    filtered: list[DuplicateGroup] = []
    for group in groups:
        if any(q in f.path.lower() for f in group.files):
            filtered.append(group)
    return filtered
