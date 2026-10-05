from __future__ import annotations

from pathlib import Path

from utils.duplicates import find_duplicates
from utils.export import export_groups_csv, export_groups_json
from utils.models import ScanSettings
from utils.scan_cache import load_cached, save_cache


def _write(path: Path, content: bytes) -> None:
    path.write_bytes(content)


def test_export_json_csv(tmp_path: Path) -> None:
    data = b"export me"
    _write(tmp_path / "a.dat", data)
    _write(tmp_path / "b.dat", data)
    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    json_path = tmp_path / "out.json"
    csv_path = tmp_path / "out.csv"
    export_groups_json(groups, json_path)
    export_groups_csv(groups, csv_path)
    body = json_path.read_text(encoding="utf-8")
    assert '"group_count": 1' in body
    assert csv_path.read_text(encoding="utf-8-sig").startswith("group_hash")


def test_export_html(tmp_path: Path) -> None:
    from utils.export import export_groups_html

    data = b"x"
    _write(tmp_path / "a", data)
    _write(tmp_path / "b", data)
    groups = find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))
    html_path = tmp_path / "r.html"
    export_groups_html(groups, html_path)
    body = html_path.read_text(encoding="utf-8")
    assert "<title>Tekrarlanan Dosya Raporu</title>" in body


def test_scan_cache_roundtrip(tmp_path: Path, monkeypatch) -> None:
    cache_dir = tmp_path / "appdata"
    monkeypatch.setattr("utils.scan_cache.APP_DIR", cache_dir)
    monkeypatch.setattr("utils.scan_cache.DB_PATH", cache_dir / "scan_cache.db")

    data = b"cached"
    _write(tmp_path / "x.bin", data)
    _write(tmp_path / "y.bin", data)
    settings = ScanSettings(roots=[str(tmp_path)], min_size_bytes=1)
    groups = find_duplicates(settings)
    save_cache(settings, groups)
    loaded = load_cached(settings)
    assert loaded is not None
    assert len(loaded) == len(groups)
