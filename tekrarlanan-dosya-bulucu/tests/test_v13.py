from __future__ import annotations

from utils.duplicates import clear_all_marks, invert_marks, mark_all_copies_for_deletion
from utils.models import DuplicateFile, DuplicateGroup
from utils.scan_cache import clear_cache
from utils.scan_history import append_scan_entry, load_history
from utils.sort_groups import SortMode, sort_groups


def _group(wasted_size: int, count: int) -> DuplicateGroup:
    files = [
        DuplicateFile(path=f"C:\\f{i}.bin", size=wasted_size, mtime=float(i))
        for i in range(count)
    ]
    return DuplicateGroup(hash_hex=f"h{wasted_size}", size=wasted_size, files=files)


def test_sort_by_wasted() -> None:
    groups = [_group(100, 2), _group(500, 2)]
    sorted_g = sort_groups(groups, SortMode.WASTED)
    assert sorted_g[0].size == 500


def test_clear_and_invert_marks() -> None:
    g = _group(10, 3)
    mark_all_copies_for_deletion([g])
    assert sum(1 for f in g.files if f.marked_for_delete) == 2
    clear_all_marks([g])
    assert not any(f.marked_for_delete for f in g.files)
    invert_marks([g])
    assert sum(1 for f in g.files if f.marked_for_delete) == 2


def test_scan_history_append(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr("utils.scan_history.HISTORY_PATH", tmp_path / "hist.json")
    append_scan_entry(scan_type="byte", roots=["C:\\A"], group_count=3, wasted_bytes=1000)
    entries = load_history()
    assert len(entries) == 1
    assert entries[0]["group_count"] == 3


def test_clear_cache(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr("utils.scan_cache.DB_PATH", tmp_path / "c.db")
    from utils.scan_cache import ensure_db

    ensure_db()
    assert clear_cache() is True
    assert clear_cache() is False
