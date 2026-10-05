from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image

IMAGE_EXTENSIONS = frozenset({".jpg", ".jpeg", ".png", ".webp", ".tiff", ".tif", ".bmp", ".heic", ".heif"})


def pixel_hash(path: Path) -> str | None:
    if path.suffix.lower() not in IMAGE_EXTENSIONS:
        return None
    try:
        with Image.open(path) as img:
            img = img.convert("RGB")
            return hashlib.sha256(img.tobytes()).hexdigest()
    except Exception:
        return None


def hash_changed(before_path: Path, after_path: Path) -> bool:
    before = pixel_hash(before_path)
    after = pixel_hash(after_path)
    if before is None or after is None:
        return False
    return before != after
