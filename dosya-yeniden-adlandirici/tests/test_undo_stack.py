from __future__ import annotations

from pathlib import Path

from core.models import PreviewRow, PreviewStatus, UndoRecord
from core.rename_ops import apply_renames
from core.undo_stack import UndoStack


def test_undo_stack_multiple_steps(tmp_path: Path):
    f1 = tmp_path / "a.txt"
    f2 = tmp_path / "b.txt"
    f1.write_text("1", encoding="utf-8")
    f2.write_text("2", encoding="utf-8")

    stack = UndoStack(max_size=5)

    rows1 = [
        PreviewRow(
            path=f1,
            original_name="a.txt",
            new_name="a1.txt",
            status=PreviewStatus.OK,
        ),
    ]
    stack.push(apply_renames(rows1))
    assert (tmp_path / "a1.txt").exists()

    rows2 = [
        PreviewRow(
            path=tmp_path / "a1.txt",
            original_name="a1.txt",
            new_name="a2.txt",
            status=PreviewStatus.OK,
        ),
        PreviewRow(
            path=f2,
            original_name="b.txt",
            new_name="b1.txt",
            status=PreviewStatus.OK,
        ),
    ]
    stack.push(apply_renames(rows2))

    n, _ = stack.undo()
    assert n == 2
    assert (tmp_path / "a1.txt").exists()
    assert f2.exists()

    n2, _ = stack.undo()
    assert n2 == 1
    assert f1.exists()


def test_undo_stack_max_size(tmp_path: Path):
    stack = UndoStack(max_size=2)
    for i in range(3):
        f = tmp_path / f"f{i}.txt"
        f.write_text("x", encoding="utf-8")
        rows = [
            PreviewRow(
                path=f,
                original_name=f.name,
                new_name=f"r{i}.txt",
                status=PreviewStatus.OK,
            )
        ]
        stack.push(apply_renames(rows))
    assert stack.depth() == 2


def _row(path: Path, new: str) -> PreviewRow:
    return PreviewRow(path=path, original_name=path.name, new_name=new, status=PreviewStatus.OK)


def test_redo_reapplies_and_new_push_clears_redo(tmp_path: Path):
    a, b = tmp_path / "a.txt", tmp_path / "b.txt"
    a.write_text("1", encoding="utf-8")
    b.write_text("2", encoding="utf-8")
    history = tmp_path / "undo.json"
    stack = UndoStack(max_size=5, path=history)
    stack.push(apply_renames([_row(a, "b.txt"), _row(b, "a.txt")]))  # takas
    assert a.read_text(encoding="utf-8") == "2"

    stack.undo()
    assert a.read_text(encoding="utf-8") == "1" and stack.can_redo()
    n, moved = stack.redo()
    assert n == 2 and a.read_text(encoding="utf-8") == "2" and not stack.can_redo()
    assert stack.depth() == 1 and set(moved) == {a, b}
    # yinelenen adım yeniden geri alınabilir; kalıcı geçmiş eski biçimde kalır
    assert UndoStack(path=history).depth() == 1
    stack.undo()
    assert a.read_text(encoding="utf-8") == "1"

    stack.push(apply_renames([_row(a, "c.txt")]))
    assert not stack.can_redo()
    assert stack.redo() == (0, [])


def test_redo_refuses_when_target_taken(tmp_path: Path):
    a = tmp_path / "a.txt"
    a.write_text("1", encoding="utf-8")
    stack = UndoStack()
    stack.push(apply_renames([_row(a, "b.txt")]))
    stack.undo()
    (tmp_path / "b.txt").write_text("başka", encoding="utf-8")
    import pytest

    with pytest.raises(OSError):
        stack.redo()
    assert a.exists() and stack.can_redo()  # hiçbir şey taşınmadı, adım korunur
