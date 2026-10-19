from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

from core import rename_ops
from core.models import PreviewRow, PreviewStatus, Rule, RuleType
from core.rename_ops import RenameError, apply_renames
from core.rules_engine import _mark_conflicts, compute_preview
from core.undo_stack import UndoStack


def _files(folder: Path, **contents: str) -> None:
    for name, text in contents.items():
        (folder / name).write_text(text, encoding="utf-8")


def _row(folder: Path, old: str, new: str, status=PreviewStatus.OK) -> PreviewRow:
    return PreviewRow(path=folder / old, original_name=old, new_name=new, status=status)


def _state(folder: Path) -> dict[str, str]:
    return {p.name: p.read_text(encoding="utf-8") for p in folder.iterdir()}


def test_case_only_rename_and_undo(tmp_path: Path):
    _files(tmp_path, **{"photo.jpg": "P"})
    stack = UndoStack()
    stack.push(apply_renames([_row(tmp_path, "photo.jpg", "PHOTO.JPG")]))
    assert _state(tmp_path) == {"PHOTO.JPG": "P"}  # os.listdir gerçek harfleri döndürür
    n, _ = stack.undo()
    assert n == 1
    assert _state(tmp_path) == {"photo.jpg": "P"}


def test_swap_and_chain(tmp_path: Path):
    _files(tmp_path, a="A", b="B", c="C")
    rec = apply_renames([_row(tmp_path, "a", "b"), _row(tmp_path, "b", "a")])
    assert _state(tmp_path) == {"a": "B", "b": "A", "c": "C"}
    rename_ops.undo_rename(rec)
    assert _state(tmp_path) == {"a": "A", "b": "B", "c": "C"}

    rec = apply_renames([_row(tmp_path, "b", "d"), _row(tmp_path, "a", "b")])
    assert _state(tmp_path) == {"b": "A", "c": "C", "d": "B"}
    rename_ops.undo_rename(rec)
    assert _state(tmp_path) == {"a": "A", "b": "B", "c": "C"}


def test_existing_target_never_overwritten(tmp_path: Path):
    _files(tmp_path, a="A", b="B", keep="KEEP")
    before = _state(tmp_path)
    for rows in (
        [_row(tmp_path, "a", "keep")],
        [_row(tmp_path, "a", "KEEP")],  # harf duyarsız çakışma (Windows)
        [_row(tmp_path, "a", "x"), _row(tmp_path, "b", "x")],  # aynı hedef
        [_row(tmp_path, "a", "b"), _row(tmp_path, "b", "keep")],  # zincirde dolu hedef
    ):
        if sys.platform != "win32" and rows[0].new_name == "KEEP":
            continue
        with pytest.raises(RenameError):
            apply_renames(rows)
        assert _state(tmp_path) == before


def test_failure_midway_rolls_back(tmp_path: Path, monkeypatch):
    _files(tmp_path, a="A", b="B", c="C")
    before = _state(tmp_path)
    real_rename = os.rename
    calls = {"n": 0}

    def flaky(src, dst):
        calls["n"] += 1
        if calls["n"] == 3:
            raise PermissionError("kilitli")
        real_rename(src, dst)

    monkeypatch.setattr(rename_ops.os, "rename", flaky)
    for rows in (
        [_row(tmp_path, "a", "x"), _row(tmp_path, "b", "y"), _row(tmp_path, "c", "z")],
        [_row(tmp_path, "a", "b"), _row(tmp_path, "b", "c"), _row(tmp_path, "c", "a")],
    ):
        calls["n"] = 0
        with pytest.raises(RenameError):
            apply_renames(rows)
        assert _state(tmp_path) == before  # geçici .__dyad_ adı kalmadı


def test_undo_blocked_keeps_step(tmp_path: Path):
    _files(tmp_path, a="A")
    stack = UndoStack()
    stack.push(apply_renames([_row(tmp_path, "a", "b")]))
    _files(tmp_path, a="NEW")  # kullanıcı eski adla yeni dosya oluşturdu
    with pytest.raises(RenameError):
        stack.undo()
    assert _state(tmp_path) == {"a": "NEW", "b": "A"}
    assert stack.depth() == 1
    (tmp_path / "a").unlink()
    assert stack.undo()[0] == 1
    assert _state(tmp_path) == {"a": "A"}


def test_undo_skips_missing(tmp_path: Path):
    _files(tmp_path, a="A", b="B")
    stack = UndoStack()
    stack.push(apply_renames([_row(tmp_path, "a", "a2"), _row(tmp_path, "b", "b2")]))
    (tmp_path / "b2").unlink()
    assert stack.undo()[0] == 1
    assert _state(tmp_path) == {"a": "A"}


def test_undo_history_persists(tmp_path: Path):
    folder = tmp_path / "f"
    folder.mkdir()
    _files(folder, a="A")
    hist = tmp_path / "undo.json"
    UndoStack(path=hist).push(apply_renames([_row(folder, "a", "b")]))
    reopened = UndoStack(path=hist)  # uygulama yeniden açıldı
    assert reopened.depth() == 1
    assert reopened.undo()[0] == 1
    assert _state(folder) == {"a": "A"}
    assert UndoStack(path=hist).depth() == 0
    hist.write_text("{bozuk", encoding="utf-8")
    assert UndoStack(path=hist).depth() == 0


def test_preview_conflicts_per_folder_and_staying_files(tmp_path: Path):
    for sub in ("x", "y"):
        (tmp_path / sub).mkdir()
        _files(tmp_path / sub, **{"a.txt": sub})
    rule = Rule(rule_type=RuleType.FIND_REPLACE, pattern="a", replacement="b")
    rows, err = compute_preview([tmp_path / "x" / "a.txt", tmp_path / "y" / "a.txt"], [rule])
    assert err is None
    assert all(r.status == PreviewStatus.OK for r in rows)

    # b hata nedeniyle yerinde kalacaksa a→b üzerine yazmamalı
    _files(tmp_path, a="A", b="B")
    rows = [_row(tmp_path, "a", "b"), _row(tmp_path, "b", "b", PreviewStatus.ERROR)]
    _mark_conflicts(rows)
    assert rows[0].status == PreviewStatus.CONFLICT


def test_preview_rejects_path_separators(tmp_path: Path):
    _files(tmp_path, **{"a_b.txt": "x"})
    rule = Rule(rule_type=RuleType.FIND_REPLACE, pattern="_", replacement="/")
    rows, _ = compute_preview([tmp_path / "a_b.txt"], [rule])
    assert rows[0].status == PreviewStatus.RESERVED


def test_main_window_smoke():
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    app = QApplication.instance() or QApplication([])
    win = MainWindow()
    assert win.centralWidget() is not None
    win.close()
