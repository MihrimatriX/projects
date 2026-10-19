from __future__ import annotations

import hashlib
from pathlib import Path

VIDEO_EXT = {".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm", ".m4v"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".svg", ".ico", ".heic"}
CODE_EXT = {".py", ".js", ".ts", ".tsx", ".jsx", ".cs", ".java", ".go", ".rs", ".cpp", ".h", ".html", ".css", ".json", ".yaml", ".yml", ".md"}
ARCHIVE_EXT = {".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".iso"}
DOC_EXT = {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".rtf"}

CLOUD_MARKERS = ("onedrive", "dropbox", "icloud", "google drive", "box sync")
SYSTEM_NAMES = {"windows", "program files", "program files (x86)", "programdata", "appdata", "$recycle.bin", "system volume information"}
CACHE_NAMES = {"node_modules", ".cache", ".npm", "__pycache__", ".venv", "venv", "dist", "build", ".git"}


def categorize(path: str, *, is_dir: bool = False) -> str:
    lower_path = path.lower().replace("/", "\\")
    name = Path(path).name.lower()

    if any(marker in lower_path for marker in CLOUD_MARKERS):
        return "cloud"
    if is_dir and name in CACHE_NAMES:
        return "system"
    if is_dir and name in SYSTEM_NAMES:
        return "system"

    ext = Path(path).suffix.lower()
    if ext in VIDEO_EXT:
        return "video"
    if ext in IMAGE_EXT:
        return "image"
    if ext in CODE_EXT:
        return "code"
    if ext in ARCHIVE_EXT:
        return "archive"
    if ext in DOC_EXT:
        return "document"
    return "default"


def cleanup_hint(path: str) -> str | None:
    name = Path(path).name.lower()
    if name in CACHE_NAMES:
        return "Temizlenebilir önbellek"
    if name == "downloads":
        return "Eski indirmeleri kontrol edin"
    if "temp" in name or name.endswith(".tmp"):
        return "Geçici dosya"
    return None


from ui.theme import CATEGORY_COLORS, FALLBACK_PALETTE


def color_for(category: str, name: str, index: int | None = None) -> str:
    """Kategori rengi; kategorisiz öğelerde `index` (kardeş sırası) verilirse paleti sırayla
    dolaşır — ad özeti komşu dilimlere sık sık aynı rengi veriyordu."""
    if category in CATEGORY_COLORS and category != "default":
        return CATEGORY_COLORS[category]
    if index is None:
        index = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    return FALLBACK_PALETTE[index % len(FALLBACK_PALETTE)]
