"""Windows Everything SDK köprüsü — Faz 3."""

from __future__ import annotations

import os
import sys
from ctypes import WinDLL, c_wchar_p, create_unicode_buffer, wintypes
from pathlib import Path

_EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME = 0x00000004
_dll: WinDLL | None = None
_dll_checked = False
_dll_error: str | None = None


def _candidate_dll_paths() -> list[Path]:
    paths: list[Path] = []
    for env in ("ProgramFiles", "ProgramFiles(x86)"):
        base = os.environ.get(env)
        if base:
            paths.append(Path(base) / "Everything" / "Everything64.dll")
    local = os.environ.get("LOCALAPPDATA")
    if local:
        paths.append(Path(local) / "Everything" / "Everything64.dll")
    return paths


def _load_dll() -> WinDLL | None:
    global _dll, _dll_checked, _dll_error
    if _dll_checked:
        return _dll
    _dll_checked = True
    if sys.platform != "win32":
        _dll_error = "Yalnızca Windows"
        return None
    last_err = "Everything64.dll bulunamadı"
    for path in _candidate_dll_paths():
        if not path.is_file():
            continue
        try:
            _dll = WinDLL(str(path))
            _bind(_dll)
            _dll_error = None
            return _dll
        except OSError as exc:
            last_err = str(exc)
    _dll_error = last_err
    return None


def _bind(dll: WinDLL) -> None:
    dll.Everything_SetSearchW.argtypes = [c_wchar_p]
    dll.Everything_SetSearchW.restype = wintypes.BOOL
    dll.Everything_SetRequestFlags.argtypes = [wintypes.DWORD]
    dll.Everything_SetRequestFlags.restype = None
    dll.Everything_SetMax.argtypes = [wintypes.DWORD]
    dll.Everything_SetMax.restype = None
    dll.Everything_QueryW.argtypes = [wintypes.BOOL]
    dll.Everything_QueryW.restype = wintypes.BOOL
    dll.Everything_GetNumResults.argtypes = []
    dll.Everything_GetNumResults.restype = wintypes.DWORD
    dll.Everything_GetResultFullPathNameW.argtypes = [
        wintypes.DWORD,
        c_wchar_p,
        wintypes.DWORD,
    ]
    dll.Everything_GetResultFullPathNameW.restype = wintypes.BOOL
    dll.Everything_Reset.argtypes = []
    dll.Everything_Reset.restype = None
    if hasattr(dll, "Everything_IsDBLoaded"):
        dll.Everything_IsDBLoaded.argtypes = []
        dll.Everything_IsDBLoaded.restype = wintypes.BOOL


def is_everything_available() -> bool:
    return _load_dll() is not None


def everything_status() -> dict:
    dll = _load_dll()
    if dll is None:
        return {"available": False, "message": _dll_error or "Everything yüklü değil"}
    db_loaded = True
    if hasattr(dll, "Everything_IsDBLoaded"):
        db_loaded = bool(dll.Everything_IsDBLoaded())
    if not db_loaded:
        return {
            "available": False,
            "message": "Everything çalışmıyor — uygulamayı başlatın",
        }
    return {"available": True, "message": "Everything bağlı"}


def _path_under_roots(path: Path, roots: list[Path]) -> bool:
    try:
        resolved = path.resolve()
    except OSError:
        return False
    for root in roots:
        try:
            resolved.relative_to(root.resolve())
            return True
        except ValueError:
            continue
    return False


def search_everything(
    query: str,
    *,
    roots: list[Path] | None = None,
    filter_to_roots: bool = True,
    max_results: int = 50,
) -> list[Path]:
    """Everything indeksinde ara; isteğe bağlı olarak kök klasörlerle filtrele."""
    needle = query.strip()
    if not needle:
        return []

    dll = _load_dll()
    if dll is None:
        return []

    status = everything_status()
    if not status.get("available"):
        return []

    dll.Everything_Reset()
    dll.Everything_SetRequestFlags(_EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME)
    dll.Everything_SetMax(max_results * 3 if filter_to_roots and roots else max_results)
    if not dll.Everything_SetSearchW(needle):
        return []
    if not dll.Everything_QueryW(True):
        return []

    count = int(dll.Everything_GetNumResults())
    buf = create_unicode_buffer(32768)
    results: list[Path] = []

    for i in range(count):
        if len(results) >= max_results:
            break
        if not dll.Everything_GetResultFullPathNameW(i, buf, 32768):
            continue
        path = Path(buf.value)
        if not path.exists():
            continue
        if filter_to_roots and roots and not _path_under_roots(path, roots):
            continue
        results.append(path)
    return results
