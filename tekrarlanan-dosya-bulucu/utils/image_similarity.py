from __future__ import annotations

import os
from collections import defaultdict
from pathlib import Path
from typing import Callable

from utils.duplicates import _collect_files, _worker_count
from utils.models import DuplicateFile, DuplicateGroup, ScanSettings

IMAGE_EXTENSIONS = frozenset(
    {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tif", ".tiff", ".heic"}
)

ProgressCallback = Callable[[str, int, str, int], None]
CancelCallback = Callable[[], bool]


def image_libs_available() -> bool:
    try:
        import imagehash  # noqa: F401
        from PIL import Image  # noqa: F401

        return True
    except ImportError:
        return False


def _phash_hex(path: Path) -> str:
    import imagehash
    from PIL import Image

    with Image.open(path) as img:
        return str(imagehash.phash(img))


def find_similar_images(
    settings: ScanSettings,
    *,
    on_progress: ProgressCallback | None = None,
    should_cancel: CancelCallback | None = None,
) -> list[DuplicateGroup]:
    if not image_libs_available():
        raise RuntimeError(
            "Görsel benzerlik için: pip install -r requirements-optional.txt"
        )

    files = _collect_files(settings, on_progress=on_progress, should_cancel=should_cancel)
    images = [p for p in files if p.suffix.lower() in IMAGE_EXTENSIONS]
    if should_cancel and should_cancel():
        return []

    by_phash: dict[str, list[Path]] = defaultdict(list)
    workers = _worker_count(settings)
    done = 0

    def work(path: Path) -> tuple[Path, str]:
        return path, _phash_hex(path)

    from concurrent.futures import ThreadPoolExecutor, as_completed

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(work, p): p for p in images}
        for future in as_completed(futures):
            if should_cancel and should_cancel():
                pool.shutdown(wait=False, cancel_futures=True)  # yoksa with çıkışı tüm kuyruğu bekler
                return []
            done += 1
            path = futures[future]
            if on_progress:
                on_progress("image", done, str(path), 0)
            try:
                _, digest = future.result()
                by_phash[digest].append(path)
            except OSError:
                continue

    groups: list[DuplicateGroup] = []
    for digest, paths in by_phash.items():
        if len(paths) < 2:
            continue
        try:
            size = paths[0].stat().st_size
        except OSError:
            size = 0
        files = []
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
                    )
                )
            except OSError:
                continue
        if len(files) >= 2:
            groups.append(
                DuplicateGroup(
                    hash_hex=f"phash-{digest}",
                    size=size,
                    files=files,
                    is_hardlink_group=False,
                )
            )
    groups.sort(key=lambda g: g.wasted_bytes, reverse=True)
    return groups
