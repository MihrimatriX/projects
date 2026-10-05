from __future__ import annotations

from pathlib import Path

import pytest

from core.categorizer import categorize, color_for, cleanup_hint
from core.formatters import human_size, percent
from core.models import ScanNode
from core.scanner import DirectoryScanner
from core.export import export_csv, export_json


def test_human_size_units():
    assert human_size(512) == "512 B"
    assert "KB" in human_size(2048)
    assert "MB" in human_size(5 * 1024 * 1024)


def test_percent():
    assert percent(25, 100) == 25.0
    assert percent(0, 0) == 0.0


def test_categorize():
    assert categorize("C:/Users/x/video.mp4") == "video"
    assert categorize("C:/Users/x/OneDrive/docs") == "cloud"
    assert categorize("C:/project/node_modules", is_dir=True) == "system"


def test_cleanup_hint():
    assert cleanup_hint("C:/x/node_modules") == "Temizlenebilir önbellek"


def test_scanner_small_tree(tmp_path: Path):
    (tmp_path / "a.txt").write_text("hello", encoding="utf-8")
    sub = tmp_path / "sub"
    sub.mkdir()
    (sub / "b.txt").write_text("x" * 100, encoding="utf-8")

    scanner = DirectoryScanner(max_depth=5)
    root = scanner.scan(str(tmp_path))
    assert root.size > 0
    assert root.file_count >= 2
    assert len(root.children) >= 2


def test_export_json_csv(tmp_path: Path):
    node = ScanNode(
        name="root",
        path="C:/root",
        size=1000,
        file_count=2,
        is_dir=True,
        children=[
            ScanNode("a", "C:/root/a", 600, 1, False),
            ScanNode("b", "C:/root/b", 400, 1, False),
        ],
    )
    json_path = tmp_path / "out.json"
    csv_path = tmp_path / "out.csv"
    export_json(node, json_path)
    export_csv(node, csv_path)
    assert json_path.exists()
    assert csv_path.exists()
    assert "root" in json_path.read_text(encoding="utf-8")
