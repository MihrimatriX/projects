from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

from utils.models import MetadataTag
from utils.tag_labels import risk_level, tag_label

_EXIFTOOL: Path | None | bool = None


def exiftool_path() -> Path | None:
    global _EXIFTOOL
    if _EXIFTOOL is False:
        return None
    if isinstance(_EXIFTOOL, Path):
        return _EXIFTOOL

    candidates: list[Path] = []
    for name in ("exiftool.exe", "exiftool"):
        found = shutil.which(name)
        if found:
            candidates.append(Path(found))

    bundled = Path(__file__).resolve().parent.parent / "sidecar" / "exiftool.exe"
    if bundled.is_file():
        candidates.insert(0, bundled)

    for candidate in candidates:
        if _verify(candidate) and _verify_checksum(candidate):
            _EXIFTOOL = candidate
            return candidate

    _EXIFTOOL = False
    return None


def is_available() -> bool:
    return exiftool_path() is not None


def _verify(path: Path) -> bool:
    try:
        result = subprocess.run(
            [str(path), "-ver"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def _verify_checksum(path: Path) -> bool:
    checksum_file = path.parent / "exiftool.sha256"
    if not checksum_file.is_file():
        return True
    line = checksum_file.read_text(encoding="utf-8").strip()
    if not line:
        return True
    expected = line.split()[0].lower()
    digest = hashlib.sha256(path.read_bytes()).hexdigest().lower()
    return digest == expected


def version() -> str | None:
    tool = exiftool_path()
    if not tool:
        return None
    try:
        result = subprocess.run(
            [str(tool), "-ver"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if result.returncode == 0:
            return (result.stdout or "").strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    return None


def run(args: list[str], files: list[Path], *, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    tool = exiftool_path()
    if not tool:
        raise RuntimeError("exiftool bulunamadı — PATH'e ekleyin veya sidecar/exiftool.exe koyun")

    cmd = [str(tool), *args, "--", *[str(f) for f in files]]
    # exiftool JSON çıktısı UTF-8'dir; Windows yerel kod sayfasıyla (cp1254) çözülürse bozulur/patlar
    return subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout, check=False
    )


def read_raw_tags(path: Path) -> dict[str, object]:
    result = run(["-json", "-G", "-a", "-s"], [path])
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "exiftool okuma hatası")
    payload = json.loads(result.stdout or "[]")
    if not payload:
        return {}
    return payload[0]


def read_tags(path: Path) -> list[MetadataTag]:
    data = read_raw_tags(path)
    tags: list[MetadataTag] = []
    skip_prefixes = ("System:", "File:")
    skip_keys = {"SourceFile", "ExifToolVersion", "FileName", "Directory", "FileSize", "FileModifyDate"}
    for key, value in data.items():
        if key in skip_keys:
            continue
        if any(key.startswith(prefix) for prefix in skip_prefixes):
            continue
        short = key.split(":", 1)[-1]
        tags.append(
            MetadataTag(
                name=key,
                label=tag_label(short),
                value=_format_value(value),
                risk=risk_level(short),
            )
        )
    tags.sort(key=lambda t: (0 if t.risk == "high" else 1, t.name))
    return tags


def strip_tags(
    path: Path,
    exiftool_args: list[str],
    *,
    backup: bool = True,
) -> tuple[list[MetadataTag], list[MetadataTag], Path | None]:
    before = read_tags(path)
    backup_path: Path | None = None
    if backup:
        backup_path = path.with_suffix(path.suffix + ".bak")
        if not backup_path.exists():
            shutil.copy2(path, backup_path)

    args = [*exiftool_args, "-overwrite_original", "-P"]
    result = run(args, [path])
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(stderr or "exiftool temizleme hatası")

    after = read_tags(path)
    return before, after, backup_path


def _format_value(value: object) -> str:
    if isinstance(value, list):
        return ", ".join(_format_value(v) for v in value)
    if isinstance(value, dict):
        return ", ".join(f"{k}={v}" for k, v in value.items())
    return str(value)
