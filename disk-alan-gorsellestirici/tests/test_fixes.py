from __future__ import annotations

import _winapi
import os
import sys
from pathlib import Path

import pytest

from core import cache
from core.models import ScanNode, is_same_or_under
from core.scanner import LARGE_FILE_THRESHOLD, DirectoryScanner, large_files_in
from core.settings import MAX_RECENT_ROOTS, AppSettings, SettingsStore


def _tree() -> ScanNode:
    return ScanNode("r", r"C:\r", 600, 3, True, children=[
        ScanNode("d", r"C:\r\d", 500, 2, True, children=[
            ScanNode("a", r"C:\r\d\a", 300, 1, False),
            ScanNode("b", r"C:\r\d\b", 200, 1, False),
        ]),
        ScanNode("c", r"C:\r\c", 100, 1, False),
    ])


def test_remove_descendant_updates_totals():
    root = _tree()
    removed = root.remove_descendant(r"c:\R\D\a")  # büyük/küçük harf duyarsız
    assert removed is not None and removed.size == 300
    assert root.size == 300 and root.file_count == 2
    assert root.children[0].size == 200
    assert root.remove_descendant(r"C:\r\yok") is None
    assert root.size == 300


def test_is_same_or_under():
    assert is_same_or_under(r"C:\r\d\a", r"C:\r")
    assert is_same_or_under("C:\\", "C:\\")
    assert not is_same_or_under(r"C:\rx", r"C:\r")


def test_scanner_counts_dot_folders(tmp_path: Path):
    git = tmp_path / ".git"
    git.mkdir()
    (git / "pack").write_bytes(b"x" * 1000)
    (tmp_path / "a.txt").write_bytes(b"y" * 10)
    root = DirectoryScanner().scan(str(tmp_path))
    assert root.size == 1010


@pytest.mark.skipif(sys.platform != "win32", reason="NTFS junction")
def test_scanner_skips_junction_cycle(tmp_path: Path):
    real = tmp_path / "real"
    real.mkdir()
    (real / "f.bin").write_bytes(b"z" * 500)
    _winapi.CreateJunction(str(tmp_path), str(real / "loop"))  # kendi üstüne döngü
    for depth in (None, 1):
        root = DirectoryScanner(max_depth=depth).scan(str(tmp_path))
        assert root.size == 500


def test_large_files_in_tree():
    big = ScanNode("big", r"C:\r\big", LARGE_FILE_THRESHOLD, 1, False)
    root = ScanNode("r", r"C:\r", big.size + 5, 2, True, children=[
        big, ScanNode("s", r"C:\r\s", 5, 1, False)])
    assert [f.path for f in large_files_in(root)] == [r"C:\r\big"]


def test_invalidate_cache_for(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(cache, "APP_DIR", tmp_path)
    monkeypatch.setattr(cache, "DB_PATH", tmp_path / "c.db")
    node = ScanNode("x", str(tmp_path), 1, 1, True)
    sub = tmp_path / "sub"
    sub.mkdir()
    other = tmp_path.parent
    cache.save_cache(str(tmp_path), node, 3)
    cache.save_cache(str(tmp_path), node, None)
    cache.save_cache(str(sub), node, 3)
    assert cache.invalidate_cache_for(str(sub / "file.bin")) == 3
    assert cache.load_cached(str(tmp_path), 3) is None
    cache.save_cache(str(sub), node, 3)
    assert cache.invalidate_cache_for(str(other / "baska")) == 0
    assert cache.load_cached(str(sub), 3) is not None


def test_remember_root_dedupes_and_caps():
    s = AppSettings()
    for i in range(MAX_RECENT_ROOTS + 3):
        s.remember_root(rf"D:\k{i}")
    s.remember_root("d:\\K0\\")
    assert s.recent_roots[0] == "d:\\K0\\"
    assert len(s.recent_roots) == MAX_RECENT_ROOTS
    assert sum(r.rstrip("\\").casefold() == r"d:\k0" for r in s.recent_roots) == 1


def test_corrupt_settings_fall_back(tmp_path: Path, monkeypatch):
    monkeypatch.setattr("core.settings.APP_DIR", tmp_path)
    path = tmp_path / "settings.json"
    monkeypatch.setattr("core.settings.SETTINGS_PATH", path)
    for content in (b"{bozuk", b"\xff\xfe\x00", b"[1, 2]"):
        path.write_bytes(content)
        assert SettingsStore()._load() == AppSettings()


def test_forget_path_updates_window(tmp_path: Path):
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    app = QApplication.instance() or QApplication([])
    win = MainWindow()
    root = _tree()
    win._root = root
    win._navigate_to(root.children[0])  # odak: C:\r\d
    win._forget_path(r"C:\r\d")
    assert root.size == 100
    assert win._focus is root
    win._set_depth_index(99)  # bozuk ayar → çökme yok
    assert win._settings.depth_index == 1
    win.close()


def test_color_for_index_gives_neighbours_distinct_colors():
    from core.categorizer import color_for

    colors = [color_for("default", name, i) for i, name in enumerate(["Videolar", "Projeler", "Fotograflar", "Oyunlar"])]
    assert len(set(colors)) == 4
    assert color_for("video", "x.mp4", 3) == color_for("video", "y.mp4")  # kategori rengi sıradan bağımsız
