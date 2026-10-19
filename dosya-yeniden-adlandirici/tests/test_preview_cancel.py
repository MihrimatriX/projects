from __future__ import annotations

from pathlib import Path

from core.models import Rule, RuleType
from core.rules_engine import compute_preview


def test_compute_preview_cancel(tmp_path: Path):
    for i in range(50):
        (tmp_path / f"f{i:03d}.txt").write_text("x", encoding="utf-8")
    files = sorted(tmp_path.glob("*.txt"))
    cancelled = {"n": 0}

    def should_cancel() -> bool:
        cancelled["n"] += 1
        return cancelled["n"] > 5

    rows, err = compute_preview(files, [Rule()], should_cancel=should_cancel)
    assert err == "Önizleme iptal edildi"
    assert len(rows) < len(files)
