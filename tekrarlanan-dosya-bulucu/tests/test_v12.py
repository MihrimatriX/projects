from __future__ import annotations

from utils.filter_groups import filter_groups
from utils.models import DuplicateFile, DuplicateGroup
from utils.scheduler import scheduled_scan_due


def _group(*paths: str) -> DuplicateGroup:
    files = [
        DuplicateFile(path=p, size=100, mtime=1.0) for p in paths
    ]
    return DuplicateGroup(hash_hex="abc", size=100, files=files)


def test_filter_groups_by_path() -> None:
    groups = [_group(r"C:\a.txt", r"C:\b.txt"), _group(r"D:\foto\1.jpg", r"D:\foto\2.jpg")]
    filtered = filter_groups(groups, "foto")
    assert len(filtered) == 1
    assert "foto" in filtered[0].files[0].path


def test_scheduled_scan_due() -> None:
    assert scheduled_scan_due(enabled=False, last_scan_utc="", interval_days=7) is False
    assert scheduled_scan_due(enabled=True, last_scan_utc="", interval_days=7) is True
    assert (
        scheduled_scan_due(
            enabled=True,
            last_scan_utc="2000-01-01T00:00:00+00:00",
            interval_days=7,
        )
        is True
    )
