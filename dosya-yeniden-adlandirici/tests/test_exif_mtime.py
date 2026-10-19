from __future__ import annotations

from datetime import datetime
from pathlib import Path

from core.exif_meta import format_exif_name, get_mtime_datetime
from core.models import Rule, RuleType
from core.rules_engine import compute_preview


def test_mtime_fallback_without_pillow(tmp_path: Path, monkeypatch):
    monkeypatch.setattr("core.exif_meta.pillow_available", lambda: False)
    f = tmp_path / "shot.jpg"
    f.write_bytes(b"not a real jpeg")
    mtime = get_mtime_datetime(f)
    assert mtime is not None

    name = format_exif_name(
        f,
        "%Y%m%d",
        f.name,
        keep_ext=True,
        use_mtime_fallback=True,
    )
    assert name.endswith(".jpg")
    assert mtime.strftime("%Y%m%d") in name


def test_exif_preview_with_mtime_rule(tmp_path: Path, monkeypatch):
    monkeypatch.setattr("core.exif_meta.pillow_available", lambda: False)
    monkeypatch.setattr("core.exif_meta.get_capture_datetime", lambda _: None)
    f = tmp_path / "x.jpg"
    f.write_text("x", encoding="utf-8")
    rules = [Rule(rule_type=RuleType.EXIF_DATE, exif_use_mtime_fallback=True)]
    rows, err = compute_preview([f], rules, exif_mtime_fallback_default=True)
    assert err is None
    assert len(rows) == 1
    assert rows[0].new_name != rows[0].original_name
