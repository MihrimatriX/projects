from __future__ import annotations

from pathlib import Path

import pytest

from core.models import PreviewStatus, Rule, RuleType
from core.rename_ops import apply_renames, undo_rename
from core.rules_engine import (
    apply_find_replace,
    apply_rules_chain,
    can_apply,
    compute_preview,
    rule_matches_file,
    validate_regex,
)


def test_find_replace_plain():
    rule = Rule(pattern="old", replacement="new", use_regex=False)
    assert apply_find_replace("old_name.txt", rule) == "new_name.txt"


def test_find_replace_ignore_case_replaces_all():
    rule = Rule(pattern="ı", replacement="i", ignore_case=True)
    assert apply_find_replace("kırmızı.txt", rule) == "kirmizi.txt"


def test_find_replace_regex():
    rule = Rule(pattern=r"IMG_(\d+)", replacement=r"Foto_\1", use_regex=True)
    assert apply_find_replace("IMG_42.jpg", rule) == "Foto_42.jpg"


def test_invalid_regex():
    assert validate_regex("[unclosed") is not None


def test_numbering_prefix():
    rules = [Rule(rule_type=RuleType.NUMBERING, pad=3, start=1)]
    assert apply_rules_chain("a.txt", rules, index=0) == "001_a.txt"
    assert apply_rules_chain("b.txt", rules, index=1) == "002_b.txt"


def test_condition_ext_filters(tmp_path: Path):
    jpg = tmp_path / "photo.jpg"
    txt = tmp_path / "note.txt"
    jpg.write_text("x", encoding="utf-8")
    txt.write_text("y", encoding="utf-8")
    rules = [
        Rule(
            rule_type=RuleType.FIND_REPLACE,
            pattern="photo",
            replacement="img",
            condition_ext="jpg",
        )
    ]
    assert rule_matches_file(rules[0], jpg)
    assert not rule_matches_file(rules[0], txt)
    rows, _ = compute_preview([jpg, txt], rules)
    jpg_row = next(r for r in rows if r.path == jpg)
    txt_row = next(r for r in rows if r.path == txt)
    assert jpg_row.new_name == "img.jpg"
    assert txt_row.new_name == "note.txt"
    assert txt_row.status == PreviewStatus.UNCHANGED


def test_conflict_same_target(tmp_path: Path):
    (tmp_path / "a.txt").write_text("x", encoding="utf-8")
    (tmp_path / "b.txt").write_text("y", encoding="utf-8")
    files = sorted(tmp_path.glob("*.txt"))
    rules = [Rule(pattern=r".*", replacement="same.txt", use_regex=True)]
    rows, err = compute_preview(files, rules)
    assert err is None
    assert any(r.status == PreviewStatus.CONFLICT for r in rows)


def test_swap_rename_two_phase(tmp_path: Path):
    from core.models import PreviewRow

    f1 = tmp_path / "a.txt"
    f2 = tmp_path / "b.txt"
    f1.write_text("1", encoding="utf-8")
    f2.write_text("2", encoding="utf-8")
    rows = [
        PreviewRow(
            path=f1,
            original_name="a.txt",
            new_name="b.txt",
            status=PreviewStatus.OK,
        ),
        PreviewRow(
            path=f2,
            original_name="b.txt",
            new_name="a.txt",
            status=PreviewStatus.OK,
        ),
    ]
    record = apply_renames(rows)
    assert (tmp_path / "b.txt").read_text(encoding="utf-8") == "1"
    assert (tmp_path / "a.txt").read_text(encoding="utf-8") == "2"
    undo_rename(record)
    assert f1.exists() and f2.exists()


def test_apply_and_undo(tmp_path: Path):
    f1 = tmp_path / "one.txt"
    f2 = tmp_path / "two.txt"
    f1.write_text("1", encoding="utf-8")
    f2.write_text("2", encoding="utf-8")
    rules = [
        Rule(pattern="one", replacement="bir", use_regex=False),
        Rule(pattern="two", replacement="iki", use_regex=False),
    ]
    rows, _ = compute_preview([f1, f2], rules)
    assert can_apply(rows)
    record = apply_renames(rows)
    assert (tmp_path / "bir.txt").exists()
    assert (tmp_path / "iki.txt").exists()
    assert undo_rename(record) == 2
    assert f1.exists()
    assert f2.exists()


def test_reserved_name(tmp_path: Path):
    f = tmp_path / "x.txt"
    f.write_text("x", encoding="utf-8")
    rules = [Rule(pattern="x", replacement="CON", use_regex=False)]
    rows, _ = compute_preview([f], rules)
    assert rows[0].status == PreviewStatus.RESERVED
