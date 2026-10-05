from __future__ import annotations

import os
from collections.abc import Callable
from pathlib import Path

from core.categorizer import categorize
from core.models import LargeFile, ScanNode

LARGE_FILE_THRESHOLD = 100 * 1024 * 1024


def _is_link(path: str | Path) -> bool:
    """Sembolik bağ / NTFS junction: izlenmez (döngü ve çift sayımı önler)."""
    p = Path(path)
    try:
        return p.is_symlink() or p.is_junction()
    except OSError:
        return True


def large_files_in(root: ScanNode) -> list[LargeFile]:
    """Ağaçtaki büyük dosyalar (önbellekten/zaman makinesinden yüklenen sonuçlar için)."""
    files = [
        LargeFile(path=n.path, name=n.name, size=n.size, category=n.category)
        for n in root.iter_flat()
        if not n.is_dir and n.size >= LARGE_FILE_THRESHOLD
    ]
    return sorted(files, key=lambda f: f.size, reverse=True)


class DirectoryScanner:
    def __init__(
        self,
        *,
        max_depth: int | None = None,
        on_progress: Callable[[int, str], None] | None = None,
        should_cancel: Callable[[], bool] | None = None,
    ) -> None:
        self.max_depth = max_depth
        self.on_progress = on_progress
        self.should_cancel = should_cancel or (lambda: False)
        self._files_scanned = 0
        self._large_files: list[LargeFile] = []

    @property
    def large_files(self) -> list[LargeFile]:
        return sorted(self._large_files, key=lambda f: f.size, reverse=True)

    def scan(self, root: str) -> ScanNode:
        root_path = Path(root).resolve()
        if not root_path.exists():
            raise FileNotFoundError(f"Yol bulunamadı: {root_path}")

        self._files_scanned = 0
        self._large_files.clear()
        node = self._scan_path(root_path, depth=0)
        if node is None:
            raise PermissionError(f"Erişim reddedildi: {root_path}")
        return node

    def _scan_path(self, path: Path, depth: int) -> ScanNode | None:
        # Özyinelemeli tarama: her klasör için ScanNode ağacı kurulur, boyutlar alttan
        # yukarı toplanır. max_depth'e ulaşan klasörlerin çocukları tutulmaz; yalnızca
        # os.walk ile toplam boyutu hesaplanır (grafikte tek dilim olarak görünür).
        if self.should_cancel():
            return None
        if depth > 0 and _is_link(path):
            return None

        is_dir = path.is_dir()
        category = categorize(str(path), is_dir=is_dir)

        if not is_dir:
            try:
                size = path.stat().st_size
            except OSError:
                return None
            self._files_scanned += 1
            self._maybe_progress(str(path))
            if size >= LARGE_FILE_THRESHOLD:
                self._large_files.append(
                    LargeFile(path=str(path), name=path.name, size=size, category=category)
                )
            return ScanNode(
                name=path.name,
                path=str(path),
                size=size,
                file_count=1,
                is_dir=False,
                category=category,
            )

        children: list[ScanNode] = []
        total_size = 0
        file_count = 0

        if self.max_depth is not None and depth >= self.max_depth:
            try:
                total_size = self._fast_dir_size(path)
                file_count = max(1, total_size // 4096)
            except OSError:
                total_size = 0
            self._maybe_progress(str(path))
            return ScanNode(
                name=path.name,
                path=str(path),
                size=total_size,
                file_count=file_count,
                is_dir=True,
                category=category,
                children=[],
            )

        try:
            entries = list(os.scandir(path))
        except OSError:
            return None

        # Nokta ile başlayan klasörler (.git, .venv, .cache…) de sayılır: disk kullanımında
        # gerçekten yer kaplarlar ve atlanırsa toplam boyut eksik görünür.
        for entry in entries:
            if self.should_cancel():
                break
            child_path = Path(entry.path)
            child = self._scan_path(child_path, depth + 1)
            if child is None:
                continue
            children.append(child)
            total_size += child.size
            file_count += child.file_count

        return ScanNode(
            name=path.name,
            path=str(path),
            size=total_size,
            file_count=file_count,
            is_dir=True,
            category=category,
            children=children,
        )

    def _fast_dir_size(self, path: Path) -> int:
        total = 0
        for root, dirs, files in os.walk(path, topdown=True, onerror=lambda _: None):
            if self.should_cancel():
                break
            # os.walk junction'ları izler; elle buda.
            dirs[:] = [d for d in dirs if not _is_link(os.path.join(root, d))]
            for name in files:
                if self.should_cancel():
                    break
                fp = Path(root) / name
                try:
                    size = fp.stat().st_size
                    total += size
                    self._files_scanned += 1
                    if size >= LARGE_FILE_THRESHOLD:
                        cat = categorize(str(fp), is_dir=False)
                        self._large_files.append(
                            LargeFile(path=str(fp), name=fp.name, size=size, category=cat)
                        )
                except OSError:
                    continue
            self._maybe_progress(str(path))
        return total

    def _maybe_progress(self, current: str) -> None:
        if self.on_progress and self._files_scanned % 200 == 0:
            self.on_progress(self._files_scanned, current)
