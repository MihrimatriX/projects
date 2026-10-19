from __future__ import annotations

from dataclasses import dataclass

from core.models import ScanNode


@dataclass
class DuplicateGroup:
    size: int
    paths: list[str]

    @property
    def count(self) -> int:
        return len(self.paths)


def find_duplicate_candidates(
    root: ScanNode,
    *,
    min_size: int = 10 * 1024 * 1024,
    max_groups: int = 30,
) -> list[DuplicateGroup]:
    by_size: dict[int, list[str]] = {}
    for node in root.iter_flat():
        if node.is_dir or node.size < min_size:
            continue
        by_size.setdefault(node.size, []).append(node.path)

    groups = [
        DuplicateGroup(size=size, paths=sorted(paths))
        for size, paths in by_size.items()
        if len(paths) >= 2
    ]
    groups.sort(key=lambda g: g.size * g.count, reverse=True)
    return groups[:max_groups]


def compare_snapshots(baseline: ScanNode, current: ScanNode) -> dict[str, int]:
    """path -> size delta (current - baseline)."""
    old_map = {n.path: n.size for n in baseline.iter_flat() if n.is_dir}
    new_map = {n.path: n.size for n in current.iter_flat() if n.is_dir}
    deltas: dict[str, int] = {}
    for path, new_size in new_map.items():
        old_size = old_map.get(path, 0)
        delta = new_size - old_size
        if delta != 0:
            deltas[path] = delta
    return deltas
