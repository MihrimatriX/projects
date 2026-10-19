from __future__ import annotations

import os
from pathlib import Path

import pytest

from utils.duplicates import (
    apply_keep_strategy,
    find_duplicates,
    mark_all_copies_for_deletion,
    marked_for_deletion,
    total_wasted_bytes,
)
from utils.models import KeepStrategy, ScanSettings


def _write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def test_finds_byte_identical_files(tmp_path: Path) -> None:
    data = b"duplicate content here"
    _write(tmp_path / "a" / "file1.txt", data)
    _write(tmp_path / "b" / "file2.txt", data)
    _write(tmp_path / "c" / "unique.txt", b"something else entirely")

    settings = ScanSettings(roots=[str(tmp_path)], min_size_bytes=1)
    groups = find_duplicates(settings)

    assert len(groups) == 1
    assert groups[0].count == 2
    assert total_wasted_bytes(groups) == len(data)


def test_skips_different_sizes(tmp_path: Path) -> None:
    _write(tmp_path / "small.txt", b"x" * 10)
    _write(tmp_path / "large.txt", b"x" * 20)

    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    assert groups == []


def test_keep_oldest_strategy(tmp_path: Path) -> None:
    data = b"same"
    _write(tmp_path / "old.txt", data)
    _write(tmp_path / "new.txt", data)

    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    apply_keep_strategy(groups, KeepStrategy.OLDEST)

    keepers = [f for g in groups for f in g.files if f.is_keeper]
    assert len(keepers) == 1
    marked = [f for g in groups for f in g.files if f.marked_for_delete]
    assert len(marked) == 1


def test_exclude_extension(tmp_path: Path) -> None:
    data = b"dup"
    _write(tmp_path / "a.txt", data)
    _write(tmp_path / "b.tmp", data)

    settings = ScanSettings(
        roots=[str(tmp_path)],
        min_size_bytes=1,
        exclude_extensions=[".tmp"],
    )
    groups = find_duplicates(settings)
    assert groups == []


def test_mark_all_copies(tmp_path: Path) -> None:
    data = b"x" * 50
    _write(tmp_path / "a.txt", data)
    _write(tmp_path / "b.txt", data)
    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    apply_keep_strategy(groups, KeepStrategy.SHORTEST_PATH)
    mark_all_copies_for_deletion(groups)
    assert len(marked_for_deletion(groups)) == 1


def test_text_preview(tmp_path: Path) -> None:
    _write(tmp_path / "a.txt", b"hello preview")
    _write(tmp_path / "b.txt", b"hello preview")
    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    assert groups[0].files[0].preview is not None


def test_hardlink_group(tmp_path: Path) -> None:
    target = tmp_path / "original.bin"
    link = tmp_path / "hardlink.bin"
    _write(target, b"linked data")
    try:
        os.link(target, link)
    except (OSError, AttributeError, NotImplementedError):
        pytest.skip("hard links unavailable on this platform")

    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    assert len(groups) == 1
    assert groups[0].is_hardlink_group
    assert groups[0].wasted_bytes == 0
    apply_keep_strategy(groups, KeepStrategy.OLDEST)
    assert marked_for_deletion(groups) == []
