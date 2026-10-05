from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

from core.duplicates import DuplicateGroup
from core.tekrarlanan_bridge import (
    APP_FOLDER,
    HANDOFF_NAME,
    argv_for_launcher,
    open_in_tekrarlanan_bulucu,
    roots_from_groups,
    _handoff_path,
    _tool_dir,
)


def test_handoff_path_formula(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "local"))
    expected = tmp_path / "local" / APP_FOLDER / HANDOFF_NAME
    assert _handoff_path() == expected


def test_roots_from_groups() -> None:
    groups = [
        DuplicateGroup(
            size=100,
            paths=[r"C:\Photos\a.jpg", r"C:\Photos\b.jpg", r"D:\other\c.jpg"],
        )
    ]
    roots = roots_from_groups(groups)
    assert r"C:\Photos" in roots
    assert r"D:\other" in roots
    assert len(roots) == 2


def test_open_without_roots() -> None:
    ok, msg = open_in_tekrarlanan_bulucu([])
    assert not ok
    assert "klasör yok" in msg.lower()


def test_handoff_written(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "local"))
    tool = tmp_path / "tekrarlanan-dosya-bulucu"
    tool.mkdir()
    (tool / "main.py").write_text("", encoding="utf-8")
    monkeypatch.setattr("core.tekrarlanan_bridge._tool_dir", lambda: tool)

    groups = [DuplicateGroup(size=1, paths=[str(tmp_path / "f1.txt"), str(tmp_path / "f2.txt")])]

    with patch("core.tekrarlanan_bridge.try_forward_subprocess", return_value=True):
        ok, _msg = open_in_tekrarlanan_bulucu(groups)
    assert ok
    data = json.loads(_handoff_path().read_text(encoding="utf-8"))
    assert data["auto_scan"] is True
    assert str(tmp_path) in data["roots"]


def test_tool_dir_points_to_sibling() -> None:
    assert _tool_dir().name == "tekrarlanan-dosya-bulucu"


def test_argv_for_launcher_main() -> None:
    argv = argv_for_launcher(Path("main.py"), ["--handoff"])
    assert argv[-1] == "--handoff"


def test_launcher_prefers_repo_dist_exe(monkeypatch, tmp_path: Path) -> None:
    import core.tekrarlanan_bridge as bridge

    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "local"))
    tool = tmp_path / "tekrarlanan-dosya-bulucu"
    tool.mkdir()
    (tool / "run.ps1").write_text("", encoding="utf-8")
    monkeypatch.setattr(bridge, "_tool_dir", lambda: tool)
    # exe yoksa run.ps1'e düşer
    assert bridge._launcher_path() == tool / "run.ps1"
    exe = tmp_path / "dist" / "tekrarlanan-dosya-bulucu" / bridge.EXE_NAME
    exe.parent.mkdir(parents=True)
    exe.write_bytes(b"")
    assert bridge._launcher_path() == exe


def test_frozen_looks_at_sibling_dist(monkeypatch, tmp_path: Path) -> None:
    import core.tekrarlanan_bridge as bridge

    me = tmp_path / "dist" / "disk-alan-gorsellestirici" / "DiskAlanGorsellestirici.exe"
    monkeypatch.setattr(bridge.sys, "frozen", True, raising=False)
    monkeypatch.setattr(bridge.sys, "executable", str(me))
    expected = tmp_path / "dist" / "tekrarlanan-dosya-bulucu" / bridge.EXE_NAME
    assert bridge._exe_candidates()[0] == expected
