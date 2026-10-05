from __future__ import annotations

import hashlib
import os
import stat
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Callable, TypeVar

from utils.models import DuplicateFile, DuplicateGroup, KeepStrategy, ScanSettings
from utils.preview import file_preview

CHUNK_SIZE = 65536
PARTIAL_BYTES = 65536

SKIP_DIR_NAMES = frozenset(
    {
        "$recycle.bin",
        "system volume information",
        "windows",
        "program files",
        "program files (x86)",
        "programdata",
        "appdata",
        "node_modules",
        ".git",
    }
)

ProgressCallback = Callable[[str, int, str, int], None]
CancelCallback = Callable[[], bool]

T = TypeVar("T")


def _worker_count(settings: ScanSettings) -> int:
    return max(1, min(settings.hash_workers, (os.cpu_count() or 4)))


def _parallel_map(
    items: list[Path],
    func: Callable[[Path], T],
    *,
    workers: int,
    should_cancel: CancelCallback | None,
    on_tick: Callable[[int, Path], None] | None,
) -> list[T]:
    if not items:
        return []
    results: list[T] = []
    done = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(func, item): item for item in items}
        for future in as_completed(futures):
            if should_cancel and should_cancel():
                pool.shutdown(wait=False, cancel_futures=True)
                return results
            path = futures[future]
            done += 1
            if on_tick:
                on_tick(done, path)
            try:
                results.append(future.result())
            except OSError:
                continue
    return results


def _is_hidden(path: Path) -> bool:
    if path.name.startswith("."):
        return True
    if sys.platform == "win32":
        try:
            attrs = path.stat().st_file_attributes
            return bool(attrs & stat.FILE_ATTRIBUTE_HIDDEN)
        except (AttributeError, OSError):
            return False
    return False


def _should_skip_dir(name: str, settings: ScanSettings) -> bool:
    lower = name.lower()
    if settings.skip_system_dirs and lower in SKIP_DIR_NAMES:
        return True
    return settings.skip_hidden and name.startswith(".")


def _extension_ok(path: Path, settings: ScanSettings) -> bool:
    if not settings.exclude_extensions:
        return True
    ext = path.suffix.lower()
    blocked = {e if e.startswith(".") else f".{e}" for e in settings.exclude_extensions}
    return ext not in blocked


def _collect_files(
    settings: ScanSettings,
    *,
    on_progress: ProgressCallback | None = None,
    should_cancel: CancelCallback | None = None,
) -> list[Path]:
    files: list[Path] = []
    scanned = 0

    for root_str in settings.roots:
        root = Path(root_str).expanduser().resolve()
        if not root.exists():
            raise FileNotFoundError(f"Klasör bulunamadı: {root}")

        stack: list[Path] = [root]
        while stack:
            if should_cancel and should_cancel():
                return files

            current = stack.pop()
            try:
                entries = list(current.iterdir())
            except OSError:
                continue

            for entry in reversed(entries):
                if should_cancel and should_cancel():
                    return files

                if entry.is_symlink() and not settings.follow_symlinks:
                    continue

                if entry.is_dir():
                    if _should_skip_dir(entry.name, settings):
                        continue
                    stack.append(entry)
                    continue

                if not entry.is_file():
                    continue
                if settings.skip_hidden and _is_hidden(entry):
                    continue
                if not _extension_ok(entry, settings):
                    continue

                try:
                    size = entry.stat().st_size
                except OSError:
                    continue
                if size < settings.min_size_bytes:
                    continue

                files.append(entry)
                scanned += 1
                if on_progress and scanned % 50 == 0:
                    on_progress("collect", scanned, str(entry), 0)

    if on_progress:
        on_progress("collect", scanned, "", 0)
    return files


def _partial_digest(path: Path) -> tuple[Path, int, str]:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        digest.update(handle.read(PARTIAL_BYTES))
    size = path.stat().st_size
    return path, size, digest.hexdigest()


def _full_digest(path: Path) -> tuple[str, str]:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(CHUNK_SIZE):
            digest.update(chunk)
    return str(path), digest.hexdigest()


def _is_hardlink_group(paths: list[Path]) -> bool:
    if len(paths) < 2:
        return False
    try:
        first = paths[0].stat()
        key = (first.st_dev, first.st_ino)
    except OSError:
        return False
    for path in paths[1:]:
        try:
            st = path.stat()
            if (st.st_dev, st.st_ino) != key:
                return False
        except OSError:
            return False
    return True


def find_duplicates(
    settings: ScanSettings,
    *,
    on_progress: ProgressCallback | None = None,
    should_cancel: CancelCallback | None = None,
) -> list[DuplicateGroup]:
    """Boyut → kısmi hash → tam SHA-256 ile mükerrer dosyaları bulur."""
    # Her aşama adayları daraltır: yalnızca aynı boyuttaki dosyaların ilk 64 KB'ı,
    # sonra yalnızca ilk 64 KB'ı da eşleşenlerin tamamı hash'lenir (iş parçacığı havuzunda).
    if not settings.roots:
        return []

    workers = _worker_count(settings)
    files = _collect_files(settings, on_progress=on_progress, should_cancel=should_cancel)
    if should_cancel and should_cancel():
        return []

    by_size: dict[int, list[Path]] = defaultdict(list)
    for path in files:
        try:
            by_size[path.stat().st_size].append(path)
        except OSError:
            continue

    size_candidates = [paths for paths in by_size.values() if len(paths) >= 2]
    partial_paths = [p for group in size_candidates for p in group]
    partial_groups: dict[tuple[int, str], list[Path]] = defaultdict(list)

    def on_partial_tick(done: int, path: Path) -> None:
        if on_progress:
            on_progress("partial", done, str(path), 0)

    for path, size, digest in _parallel_map(
        partial_paths,
        _partial_digest,
        workers=workers,
        should_cancel=should_cancel,
        on_tick=on_partial_tick,
    ):
        partial_groups[(size, digest)].append(path)
    if should_cancel and should_cancel():
        return []

    full_candidates = [paths for paths in partial_groups.values() if len(paths) >= 2]
    full_paths = [p for group in full_candidates for p in group]
    result_groups: dict[str, list[Path]] = defaultdict(list)

    def on_full_tick(done: int, path: Path) -> None:
        if on_progress:
            groups_so_far = sum(1 for p_list in result_groups.values() if len(p_list) >= 2)
            on_progress("full", done, str(path), groups_so_far)

    full_results = _parallel_map(
        full_paths,
        _full_digest,
        workers=workers,
        should_cancel=should_cancel,
        on_tick=on_full_tick,
    )
    if should_cancel and should_cancel():
        return []
    for path_str, digest in full_results:
        result_groups[digest].append(Path(path_str))

    return _build_groups(result_groups)


def _build_groups(by_hash: dict[str, list[Path]]) -> list[DuplicateGroup]:
    groups: list[DuplicateGroup] = []
    for digest, paths in by_hash.items():
        if len(paths) < 2:
            continue
        try:
            size = paths[0].stat().st_size
        except OSError:
            continue
        files: list[DuplicateFile] = []
        for path in sorted(paths, key=lambda p: str(p).lower()):
            try:
                st = path.stat()
                files.append(
                    DuplicateFile(
                        path=str(path),
                        size=st.st_size,
                        mtime=st.st_mtime,
                        inode=st.st_ino,
                        device=st.st_dev,
                        preview=file_preview(str(path)),
                    )
                )
            except OSError:
                continue
        if len(files) >= 2:
            groups.append(
                DuplicateGroup(
                    hash_hex=digest,
                    size=size,
                    files=files,
                    is_hardlink_group=_is_hardlink_group(paths),
                )
            )

    groups.sort(key=lambda g: g.wasted_bytes, reverse=True)
    return groups


def total_wasted_bytes(groups: list[DuplicateGroup]) -> int:
    return sum(g.wasted_bytes for g in groups)


def parse_protected_folders(text: str) -> list[str]:
    """';' ile ayrılmış korunan klasör listesini normalleştirir."""
    return [
        os.path.normcase(os.path.abspath(os.path.expanduser(p.strip())))
        for p in text.split(";")
        if p.strip()
    ]


def is_protected(path: str, protected: list[str]) -> bool:
    p = os.path.normcase(os.path.abspath(path))
    return any(p == d or p.startswith(d.rstrip(os.sep) + os.sep) for d in protected)


def apply_keep_strategy(
    groups: list[DuplicateGroup],
    strategy: KeepStrategy,
    protected: list[str] | None = None,
) -> None:
    """Her grupta bir kopyayı tutar. Korunan klasörlerdeki dosyalar her zaman tutulur
    (dupeGuru'daki "referans klasör"); tutulacak kopya önce bunlar arasından seçilir."""
    protected = protected or []
    for group in groups:
        if not group.files:
            continue
        if group.is_hardlink_group:
            for item in group.files:
                item.is_keeper = True
                item.marked_for_delete = False
            continue
        guarded = {f.path for f in group.files if protected and is_protected(f.path, protected)}
        pool = [f for f in group.files if f.path in guarded] or group.files
        keeper = _pick_keeper(pool, strategy)
        for item in group.files:
            item.is_keeper = item.path == keeper.path or item.path in guarded
            item.marked_for_delete = not item.is_keeper


def _pick_keeper(files: list[DuplicateFile], strategy: KeepStrategy) -> DuplicateFile:
    if strategy == KeepStrategy.OLDEST:
        return min(files, key=lambda f: f.mtime)
    if strategy == KeepStrategy.NEWEST:
        return max(files, key=lambda f: f.mtime)
    return min(files, key=lambda f: len(f.path))


def marked_for_deletion(groups: list[DuplicateGroup]) -> list[str]:
    return [f.path for g in groups for f in g.files if f.marked_for_delete]


def mark_all_copies_for_deletion(groups: list[DuplicateGroup]) -> None:
    for group in groups:
        if group.is_hardlink_group:
            continue
        if group.files and not any(item.is_keeper for item in group.files):
            _pick_keeper(group.files, KeepStrategy.OLDEST).is_keeper = True
        for item in group.files:
            if not item.is_keeper:
                item.marked_for_delete = True


def clear_all_marks(groups: list[DuplicateGroup]) -> None:
    for group in groups:
        for item in group.files:
            if not item.is_keeper:
                item.marked_for_delete = False


def invert_marks(groups: list[DuplicateGroup]) -> None:
    for group in groups:
        if group.is_hardlink_group:
            continue
        for item in group.files:
            if not item.is_keeper:
                item.marked_for_delete = not item.marked_for_delete
