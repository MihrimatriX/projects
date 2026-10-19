from __future__ import annotations

from pathlib import Path

from utils.handoff import build_handoff_payload
from utils.models import DuplicateFile, DuplicateGroup
from utils.session import load_session, save_session


def test_build_handoff_payload(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(
        "utils.handoff.HANDOFF_PATH",
        tmp_path / "handoff.json",
    )
    from utils.handoff import write_handoff

    write_handoff([r"C:\A", r"D:\B"], auto_scan=True)
    payload = build_handoff_payload(["--handoff"])
    assert r"C:\A" in payload["roots"]
    assert payload["auto_scan"] is True


def test_session_roundtrip(tmp_path: Path) -> None:
    groups = [
        DuplicateGroup(
            hash_hex="abc123",
            size=50,
            files=[
                DuplicateFile(path="/a/f1", size=50, mtime=1.0, is_keeper=True),
                DuplicateFile(path="/a/f2", size=50, mtime=2.0, marked_for_delete=True),
            ],
        )
    ]
    path = tmp_path / "sess.json"
    save_session(groups, path)
    loaded = load_session(path)
    assert len(loaded) == 1
    assert loaded[0].files[1].marked_for_delete
