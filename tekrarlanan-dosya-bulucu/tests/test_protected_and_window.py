from __future__ import annotations

import json
from pathlib import Path

import pytest

from utils import settings as settings_mod
from utils.duplicates import (
    apply_keep_strategy,
    find_duplicates,
    invert_marks,
    is_protected,
    mark_all_copies_for_deletion,
    marked_for_deletion,
    parse_protected_folders,
)
from utils.models import KeepStrategy, ScanSettings


def _write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


@pytest.fixture
def dupes(tmp_path: Path):
    data = b"ayni icerik"
    _write(tmp_path / "a" / "x.txt", data)
    _write(tmp_path / "arsiv" / "derin" / "uzun_adli_kopya.txt", data)
    _write(tmp_path / "b" / "y.txt", data)
    return tmp_path, find_duplicates(ScanSettings(roots=[str(tmp_path)], min_size_bytes=1))


def test_parse_and_is_protected(tmp_path: Path) -> None:
    folders = parse_protected_folders(f" {tmp_path / 'arsiv'} ; ;")
    assert len(folders) == 1
    assert is_protected(str(tmp_path / "arsiv" / "f.txt"), folders)
    assert is_protected(str(tmp_path / "ARSIV" / "f.txt"), folders)  # Windows: büyük/küçük harf duyarsız
    assert not is_protected(str(tmp_path / "arsiv2" / "f.txt"), folders)  # önek ama farklı klasör


def test_protected_folder_wins_keep_strategy(dupes) -> None:
    root, groups = dupes
    protected = parse_protected_folders(str(root / "arsiv"))
    # En kısa yol stratejisi normalde arsiv/derin/... kopyasını silerdi
    apply_keep_strategy(groups, KeepStrategy.SHORTEST_PATH, protected)
    marked = marked_for_deletion(groups)
    assert len(marked) == 2
    assert not any("arsiv" in p for p in marked)


def test_protected_survives_bulk_mark_and_invert(dupes) -> None:
    root, groups = dupes
    protected = parse_protected_folders(f"{root / 'arsiv'};{root / 'b'}")
    apply_keep_strategy(groups, KeepStrategy.OLDEST, protected)
    mark_all_copies_for_deletion(groups)
    invert_marks(groups)
    invert_marks(groups)
    assert [Path(p).parent.name for p in marked_for_deletion(groups)] == ["a"]


def test_corrupt_settings_fall_back_to_defaults(tmp_path: Path, monkeypatch) -> None:
    bad = tmp_path / "settings.json"
    bad.write_bytes(b"\xff\xfe\x00garbage")
    monkeypatch.setattr(settings_mod, "SETTINGS_PATH", bad)
    monkeypatch.setattr(settings_mod, "APP_DIR", tmp_path)
    assert settings_mod.SettingsStore().settings.protected_folders == ""
    bad.write_text("[1, 2]", encoding="utf-8")
    assert settings_mod.SettingsStore().settings.min_size_kb == 1


@pytest.fixture
def window(tmp_path: Path, monkeypatch):
    from PySide6.QtWidgets import QApplication

    app = QApplication.instance() or QApplication([])
    path = tmp_path / "settings.json"
    path.write_text(json.dumps({"roots": [], "protected_folders": ""}), encoding="utf-8")
    monkeypatch.setattr(settings_mod, "SETTINGS_PATH", path)
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    from ui.main_window import MainWindow

    w = MainWindow()
    yield w
    w._schedule_timer.stop()
    w.deleteLater()
    app.processEvents()


def test_window_opens_and_applies_protected_folders(window, dupes) -> None:
    root, groups = dupes
    window._store.settings.protected_folders = str(root / "arsiv")
    window._all_groups = groups
    window._apply_keep()
    window._render_groups()
    window._update_delete_button()
    assert window.delete_btn.isEnabled()
    assert not any("arsiv" in p for p in marked_for_deletion(window._all_groups))


def test_export_error_is_reported_not_raised(window, dupes, tmp_path: Path, monkeypatch) -> None:
    from ui import main_window as mw

    _root, groups = dupes
    window._all_groups = groups
    target = tmp_path / "yok_klasor" / "rapor.json"  # üst klasör yok -> OSError
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: (str(target), ""))
    errors = []
    monkeypatch.setattr(mw.QMessageBox, "critical", lambda *a, **k: errors.append(a))
    window._export_json()
    assert errors and not target.exists()
