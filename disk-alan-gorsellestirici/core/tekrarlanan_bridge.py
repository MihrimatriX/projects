from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from core.duplicates import DuplicateGroup

HANDOFF_NAME = "handoff.json"
APP_FOLDER = "TekrarlananDosyaBulucu"


def _app_data_dir() -> Path:
    """tekrarlanan-dosya-bulucu utils/settings.py ile aynı kök."""
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return Path(base) / APP_FOLDER


def _handoff_path() -> Path:
    path = _app_data_dir() / HANDOFF_NAME
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _tool_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "tekrarlanan-dosya-bulucu"


EXE_NAME = "TekrarlananDosyaBulucu.exe"
DIST_FOLDER = "tekrarlanan-dosya-bulucu"


def _exe_candidates() -> list[Path]:
    """Derlenmiş exe aranacak yerler (öncelik sırasıyla)."""
    candidates: list[Path] = []
    if getattr(sys, "frozen", False):
        # Bu uygulama <repo>\dist\disk-alan-gorsellestirici\ altından çalışıyorsa kardeş klasör.
        candidates.append(Path(sys.executable).resolve().parent.parent / DIST_FOLDER / EXE_NAME)
    # Kaynaktan çalışırken: <repo>\dist\tekrarlanan-dosya-bulucu\ (publish.ps1 çıktısı).
    candidates.append(_tool_dir().parent / "dist" / DIST_FOLDER / EXE_NAME)
    # install.ps1 ile kurulmuş sürüm.
    local = os.environ.get("LOCALAPPDATA")
    if local:
        candidates.append(Path(local) / "Programs" / APP_FOLDER / EXE_NAME)
    return candidates


def _launcher_path() -> Path | None:
    for exe in _exe_candidates():
        if exe.is_file():
            return exe
    tool = _tool_dir()
    if sys.platform == "win32":
        run_ps1 = tool / "run.ps1"
        if run_ps1.exists():
            return run_ps1
    else:
        run_sh = tool / "run.sh"
        if run_sh.exists():
            return run_sh
    main_py = tool / "main.py"
    if main_py.exists():
        return main_py
    return None


def argv_for_launcher(launcher: Path, extra_args: list[str]) -> list[str]:
    name = launcher.name.lower()
    if name.endswith(".exe"):
        return [str(launcher), *extra_args]
    if name == "run.ps1" and sys.platform == "win32":
        return [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(launcher),
            *extra_args,
        ]
    if name == "run.sh":
        return [str(launcher), *extra_args]
    return [sys.executable, str(launcher), *extra_args]


def try_forward_subprocess(launcher: Path, *, timeout: int = 10) -> bool:
    try:
        result = subprocess.run(
            argv_for_launcher(launcher, ["--forward-handoff", "--handoff"]),
            cwd=str(launcher.parent),
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def _spawn_launcher(launcher: Path) -> None:
    subprocess.Popen(
        argv_for_launcher(launcher, ["--handoff"]),
        cwd=str(launcher.parent),
    )


def roots_from_groups(groups: list[DuplicateGroup]) -> list[str]:
    dirs: set[str] = set()
    for group in groups:
        for path in group.paths:
            dirs.add(str(Path(path).parent))
    return sorted(dirs)


def open_in_tekrarlanan_bulucu(groups: list[DuplicateGroup]) -> tuple[bool, str]:
    roots = roots_from_groups(groups)
    if not roots:
        return False, "Aktarılacak klasör yok."

    payload = {"roots": roots, "auto_scan": True}
    _handoff_path().write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    launcher = _launcher_path()
    if not launcher:
        return False, "tekrarlanan-dosya-bulucu bulunamadı (kardeş klasör)."

    if try_forward_subprocess(launcher):
        return True, f"{len(roots)} klasör çalışan örneğe IPC ile aktarıldı."

    _spawn_launcher(launcher)
    return True, f"{len(roots)} klasör aktarıldı — uygulama başlatılıyor."
