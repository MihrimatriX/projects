from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap

from utils.config import IMAGE_EXTENSIONS, PREVIEW_SIZE

_CACHE: dict[str, QPixmap] = {}


def is_image_path(path: Path) -> bool:
    return path.suffix.lower() in IMAGE_EXTENSIONS


def load_thumbnail(path: Path, size: int = PREVIEW_SIZE) -> QPixmap | None:
    key = f"{path.resolve()}:{size}"
    if key in _CACHE:
        return _CACHE[key]

    if not path.is_file() or path.suffix.lower() not in IMAGE_EXTENSIONS:
        return None
    try:
        if path.stat().st_size > 20 * 1024 * 1024:
            return None
        pix = QPixmap(str(path))
        if pix.isNull():
            return None
        scaled = pix.scaled(
            size,
            size,
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )
        _CACHE[key] = scaled
        if len(_CACHE) > 80:
            _CACHE.clear()
        return scaled
    except OSError:
        return None


def file_ext_label(suffix: str) -> str:
    """Dosya uzantısı etiketi — emoji yerine mono kısa etiket."""
    s = suffix.lower().lstrip(".")
    if not s:
        return "?"
    return s[:4]


def format_file_size(path: Path) -> str:
    try:
        size = path.stat().st_size
    except OSError:
        return ""
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size // 1024} KB"
    return f"{size / (1024 * 1024):.1f} MB".replace(".", ",")


def file_emoji(suffix: str) -> str:
    """Geriye dönük uyumluluk — yeni UI file_ext_label kullanır."""
    return file_ext_label(suffix)
