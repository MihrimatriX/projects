from __future__ import annotations

import os
from pathlib import Path


def test_handoff_path_matches_settings() -> None:
    from utils.handoff import HANDOFF_PATH
    from utils.settings import APP_DIR

    assert HANDOFF_PATH == APP_DIR / "handoff.json"


def test_disk_bridge_handoff_formula(monkeypatch, tmp_path: Path) -> None:
    """Disk köprüsü _app_data_dir() ile settings._app_dir aynı formül."""
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "local"))
    monkeypatch.delenv("TEKRARLANAN_DATA_DIR", raising=False)  # köprü override bilmez; varsayılan formül
    from utils.app_info import APP_ID
    from utils.settings import _app_dir

    disk_handoff = Path(os.environ["LOCALAPPDATA"]) / APP_ID / "handoff.json"
    assert _app_dir() / "handoff.json" == disk_handoff
