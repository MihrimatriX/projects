from __future__ import annotations

from core.duplicates import compare_snapshots, find_duplicate_candidates
from core.history import append_history, list_history, load_snapshot
from core.models import ScanNode
from core.settings import SettingsStore


def test_find_duplicates():
    root = ScanNode(
        name="r",
        path="C:/r",
        size=200,
        file_count=2,
        is_dir=True,
        children=[
            ScanNode("a", "C:/r/a", 100, 1, False),
            ScanNode("b", "C:/r/b", 100, 1, False),
            ScanNode("c", "C:/r/c", 50, 1, False),
        ],
    )
    groups = find_duplicate_candidates(root, min_size=50)
    assert len(groups) == 1
    assert groups[0].count == 2


def test_compare_snapshots():
    old = ScanNode("r", "C:/r", 100, 1, True, children=[
        ScanNode("d", "C:/r/d", 100, 1, True),
    ])
    new = ScanNode("r", "C:/r", 150, 1, True, children=[
        ScanNode("d", "C:/r/d", 150, 1, True),
    ])
    deltas = compare_snapshots(old, new)
    assert deltas["C:/r/d"] == 50


def test_settings_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr("core.settings.APP_DIR", tmp_path)
    monkeypatch.setattr("core.settings.SETTINGS_PATH", tmp_path / "settings.json")
    SettingsStore._instance = None
    store = SettingsStore()
    store.settings.last_scan_root = "D:\\test"
    store.save()
    SettingsStore._instance = None
    store2 = SettingsStore()
    assert store2.settings.last_scan_root == "D:\\test"


def test_history_append_and_load(tmp_path, monkeypatch):
    monkeypatch.setattr("core.cache.APP_DIR", tmp_path)
    monkeypatch.setattr("core.cache.DB_PATH", tmp_path / "db.sqlite")
    monkeypatch.setattr("core.history.DB_PATH", tmp_path / "db.sqlite")
    node = ScanNode("root", "C:/root", 500, 3, True)
    sid = append_history("C:/root", node)
    assert sid > 0
    snaps = list_history("C:/root")
    assert len(snaps) == 1
    loaded = load_snapshot(snaps[0].id)
    assert loaded is not None
    assert loaded.size == 500
