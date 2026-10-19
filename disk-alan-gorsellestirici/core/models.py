from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Iterator


@dataclass
class ScanNode:
    name: str
    path: str
    size: int
    file_count: int
    is_dir: bool
    category: str = "default"
    children: list[ScanNode] = field(default_factory=list)

    def sorted_children(self) -> list[ScanNode]:
        return sorted(self.children, key=lambda c: c.size, reverse=True)

    def iter_flat(self) -> Iterator[ScanNode]:
        yield self
        for child in self.children:
            yield from child.iter_flat()

    def remove_descendant(self, path: str) -> ScanNode | None:
        """path'teki alt düğümü ağaçtan çıkarır, üst klasörlerin boyut/dosya sayısını
        düşer ve çıkarılan düğümü döndürür (bulunamazsa None)."""
        target = _norm(path)
        for i, child in enumerate(self.children):
            cp = _norm(child.path)
            if cp == target:
                removed = self.children.pop(i)
            elif child.is_dir and target.startswith(cp + os.sep):
                removed = child.remove_descendant(path)
            else:
                continue
            if removed is not None:
                self.size -= removed.size
                self.file_count -= removed.file_count
            return removed
        return None

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "path": self.path,
            "size": self.size,
            "file_count": self.file_count,
            "is_dir": self.is_dir,
            "category": self.category,
            "children": [c.to_dict() for c in self.children],
        }

    @classmethod
    def from_dict(cls, data: dict) -> ScanNode:
        return cls(
            name=data["name"],
            path=data["path"],
            size=data["size"],
            file_count=data["file_count"],
            is_dir=data["is_dir"],
            category=data.get("category", "default"),
            children=[cls.from_dict(c) for c in data.get("children", [])],
        )


@dataclass
class LargeFile:
    path: str
    name: str
    size: int
    category: str


def _norm(path: str) -> str:
    return os.path.normcase(os.path.normpath(path)).rstrip("\\/")


def is_same_or_under(path: str, ancestor: str) -> bool:
    p, a = _norm(path), _norm(ancestor)
    return p == a or p.startswith(a + os.sep)
