from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from utils.settings import APP_DIR

HANDOFF_PATH = APP_DIR / "handoff.json"


def write_handoff(roots: list[str], *, auto_scan: bool = True) -> Path:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    payload = {"roots": roots, "auto_scan": auto_scan}
    HANDOFF_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return HANDOFF_PATH


def read_handoff() -> dict | None:
    if not HANDOFF_PATH.exists():
        return None
    try:
        return json.loads(HANDOFF_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def clear_handoff() -> None:
    if HANDOFF_PATH.exists():
        HANDOFF_PATH.unlink()


def parse_cli_roots(argv: list[str]) -> list[str]:
    roots: list[str] = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("--roots", "-r") and i + 1 < len(argv):
            roots.extend(p.strip() for p in argv[i + 1].split(";") if p.strip())
            i += 2
            continue
        if arg == "--handoff":
            data = read_handoff()
            if data and data.get("roots"):
                roots.extend(data["roots"])
            i += 1
            continue
        i += 1
    return roots


def should_auto_scan(argv: list[str]) -> bool:
    if "--handoff" in argv:
        data = read_handoff()
        return bool(data and data.get("auto_scan", True))
    return "--scan" in argv


def build_handoff_payload(argv: list[str]) -> dict:
    """CLI + handoff dosyasından IPC/file payload üretir."""
    roots = list(parse_cli_roots(argv))
    auto = should_auto_scan(argv)
    if "--handoff" in argv:
        data = read_handoff()
        if data:
            for r in data.get("roots", []):
                if r not in roots:
                    roots.append(r)
            auto = bool(data.get("auto_scan", auto))
    return {"roots": roots, "auto_scan": auto}


def launcher_candidates(project_root: Path) -> list[Path]:
    # publish.ps1 çıktısı: <repo>/dist/tekrarlanan-dosya-bulucu/TekrarlananDosyaBulucu.exe
    candidates: list[Path] = [
        project_root.parent / "dist" / project_root.name / "TekrarlananDosyaBulucu.exe"
    ]
    if sys.platform == "win32":
        candidates.append(project_root / "run.ps1")
    else:
        candidates.append(project_root / "run.sh")
    candidates.append(project_root / "main.py")
    return candidates


def find_project_launcher() -> Path | None:
    here = Path(__file__).resolve().parent.parent
    for candidate in launcher_candidates(here):
        if candidate.exists():
            return candidate
    return None


def argv_for_launcher(launcher: Path, extra_args: list[str]) -> list[str]:
    """Başlatıcı türüne göre subprocess argv (disk köprüsü ile uyumlu)."""
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


def _spawn_launcher(launcher: Path, extra_args: list[str]) -> None:
    subprocess.Popen(
        argv_for_launcher(launcher, extra_args),
        cwd=str(launcher.parent),
    )


def launch_app(roots: list[str], *, auto_scan: bool = True) -> bool:
    write_handoff(roots, auto_scan=auto_scan)
    launcher = find_project_launcher()
    if not launcher:
        return False
    if try_forward_subprocess(launcher):
        return True
    _spawn_launcher(launcher, ["--handoff"])
    return True
