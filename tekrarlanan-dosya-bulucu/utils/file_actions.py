from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def reveal_in_file_manager(path: str) -> None:
    p = Path(path).resolve()
    if sys.platform == "win32":
        if p.is_file():
            subprocess.run(["explorer", "/select,", str(p)], check=False)
        elif p.exists():
            subprocess.run(["explorer", str(p)], check=False)
    elif sys.platform == "darwin":
        subprocess.run(["open", "-R", str(p)] if p.is_file() else ["open", str(p)], check=False)
    else:
        subprocess.run(["xdg-open", str(p.parent if p.is_file() else p)], check=False)


def open_with_default_app(path: str) -> None:
    p = Path(path)
    if not p.is_file():
        return
    if sys.platform == "win32":
        os.startfile(str(p))  # noqa: S606
    elif sys.platform == "darwin":
        subprocess.run(["open", str(p)], check=False)
    else:
        subprocess.run(["xdg-open", str(p)], check=False)


def move_to_trash(paths: list[str]) -> tuple[int, list[str]]:
    from send2trash import send2trash

    ok = 0
    errors: list[str] = []
    for path in paths:
        try:
            send2trash(path)
            ok += 1
        except OSError as exc:
            errors.append(f"{path}: {exc}")
    return ok, errors


# Geriye uyumluluk
reveal_in_explorer = reveal_in_file_manager
