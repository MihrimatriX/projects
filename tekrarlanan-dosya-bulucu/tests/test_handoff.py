from __future__ import annotations

from utils.handoff import parse_cli_roots, write_handoff


def test_handoff_roundtrip(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr("utils.handoff.HANDOFF_PATH", tmp_path / "handoff.json")
    write_handoff([r"C:\Test", r"D:\Photos"], auto_scan=True)
    roots = parse_cli_roots(["--handoff"])
    assert r"C:\Test" in roots
    assert r"D:\Photos" in roots
