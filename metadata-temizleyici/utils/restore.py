from __future__ import annotations

import json
import shutil
from pathlib import Path


def backup_path_for(file_path: Path) -> Path:
    return file_path.with_suffix(file_path.suffix + ".bak")


def has_backup(file_path: Path) -> bool:
    return backup_path_for(file_path).is_file()


def restore_backup(file_path: Path) -> Path:
    src = Path(file_path).resolve()
    backup = backup_path_for(src)
    if not backup.is_file():
        raise FileNotFoundError(f"Yedek bulunamadı: {backup.name}")
    shutil.copy2(backup, src)
    return src
