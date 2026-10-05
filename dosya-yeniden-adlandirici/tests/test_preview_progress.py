from __future__ import annotations

from pathlib import Path

from core.models import Rule
from core.rules_engine import compute_preview


def test_on_progress_callback(tmp_path: Path):
    for i in range(12):
        (tmp_path / f"f{i}.txt").write_text("x", encoding="utf-8")
    files = sorted(tmp_path.glob("*.txt"))
    calls: list[tuple[int, int]] = []

    compute_preview(
        files,
        [Rule()],
        on_progress=lambda done, total: calls.append((done, total)),
    )
    assert calls
    assert calls[-1] == (12, 12)
