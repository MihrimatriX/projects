from __future__ import annotations

from datetime import datetime
from pathlib import Path

from core.exif_meta import format_exif_name
from core.models import ExifNamingMode


def test_exif_and_mtime_combined(tmp_path: Path, monkeypatch):
    f = tmp_path / "photo.jpg"
    f.write_bytes(b"x")
    fixed = datetime(2024, 3, 15, 14, 30, 22)
    mtime = datetime(2024, 3, 20, 9, 0, 0)
    monkeypatch.setattr("core.exif_meta.get_capture_datetime", lambda _: fixed)
    monkeypatch.setattr("core.exif_meta.get_mtime_datetime", lambda _: mtime)

    name = format_exif_name(
        f,
        "%Y%m%d_%H%M%S",
        f.name,
        keep_ext=True,
        use_mtime_fallback=True,
        naming_mode=ExifNamingMode.EXIF_AND_MTIME,
        mtime_format="%Y%m%d",
        separator="_",
    )
    assert name == "20240315_143022_20240320.jpg"


def test_mtime_only_mode(tmp_path: Path, monkeypatch):
    f = tmp_path / "doc.pdf"
    f.write_bytes(b"x")
    mtime = datetime(2025, 1, 2, 8, 0, 0)
    monkeypatch.setattr("core.exif_meta.get_capture_datetime", lambda _: None)
    monkeypatch.setattr("core.exif_meta.get_mtime_datetime", lambda _: mtime)

    name = format_exif_name(
        f,
        "%Y-%m-%d",
        f.name,
        keep_ext=True,
        use_mtime_fallback=False,
        naming_mode=ExifNamingMode.MTIME_ONLY,
    )
    assert name == "2025-01-02.pdf"
