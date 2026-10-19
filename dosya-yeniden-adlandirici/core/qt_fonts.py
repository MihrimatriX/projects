from __future__ import annotations

import os
import shutil
from pathlib import Path


def ensure_qt_font_directory() -> None:
    """PySide6 6.7+ Qt gömülü font taşımıyor; lib/fonts boşsa sistem fontlarını kopyala."""
    try:
        from PySide6 import QtCore
    except ImportError:
        return

    font_dir = Path(QtCore.__file__).resolve().parent / "lib" / "fonts"
    if font_dir.exists() and any(font_dir.glob("*.ttf")):
        return

    font_dir.mkdir(parents=True, exist_ok=True)

    if os.name != "nt":
        return

    win_fonts = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    for name in ("segoeui.ttf", "segoeuib.ttf", "consola.ttf"):
        src = win_fonts / name
        if src.is_file():
            dest = font_dir / name
            if not dest.exists():
                try:
                    shutil.copy2(src, dest)
                except OSError:
                    pass
