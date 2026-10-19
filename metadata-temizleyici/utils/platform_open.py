from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def reveal_in_folder(path: Path) -> None:
    resolved = Path(path).resolve()
    if not resolved.exists():
        raise FileNotFoundError(resolved)

    if sys.platform == "win32":
        subprocess.run(["explorer", "/select,", str(resolved)], check=False)
    elif sys.platform == "darwin":
        subprocess.run(["open", "-R", str(resolved)], check=False)
    else:
        subprocess.run(["xdg-open", str(resolved.parent)], check=False)
