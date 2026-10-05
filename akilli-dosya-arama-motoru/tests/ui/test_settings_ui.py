"""İndeks ayarları diyaloğu ve tepsi menüsü: her düğme, onay kutusu ve alan gerçekten çalışır."""

from pathlib import Path

import pytest
from PySide6.QtCore import Qt
from PySide6.QtWidgets import QCheckBox, QMessageBox, QPushButton, QSpinBox, QToolButton

from ui import settings_dialog as sd
from ui.settings_dialog import SettingsDialog, _FolderRow
from ui.tray_menu import TrayMenu
from utils import search_history
from utils.index_backend import get_index_stats
from utils.settings import load_settings


@pytest.fixture
def dlg(qtbot, demo_root):
    d = SettingsDialog()
    qtbot.addWidget(d)
    d.show()
    qtbot.waitExposed(d)
    return d


@pytest.fixture
def msgs(monkeypatch):
    seen = []
    for kind in ("warning", "information"):
        monkeypatch.setattr(sd.QMessageBox, kind, lambda *a, k=kind, **kw: seen.append((k, a[1], a[2])))
    monkeypatch.setattr(sd.QMessageBox, "question", lambda *a, **kw: QMessageBox.StandardButton.Yes)
    return seen


def _button(d, text):
    return next(b for b in d.findChildren(QPushButton) if b.text() == text)


def test_every_control_has_accessible_name(dlg):
    for cb in dlg.findChildren(QCheckBox) + dlg.findChildren(QSpinBox):
        assert cb.accessibleName(), cb
    for b in dlg.findChildren(QToolButton):
        assert b.accessibleName(), b
    folder_rows = dlg.findChildren(_FolderRow)
    assert len(folder_rows) == 1 and folder_rows[0].toolTip().endswith("Projeler")


def test_add_and_remove_folder(qtbot, dlg, demo_root, tmp_path, monkeypatch, msgs):
    extra = tmp_path / "home" / "Belgeler"
    extra.mkdir()
    monkeypatch.setattr(sd.QFileDialog, "getExistingDirectory", lambda *a, **k: str(extra))
    qtbot.mouseClick(_button(dlg, "+ Dizin ekle"), Qt.MouseButton.LeftButton)
    assert len(dlg._folders) == 2
    qtbot.mouseClick(_button(dlg, "+ Dizin ekle"), Qt.MouseButton.LeftButton)  # aynı klasör iki kez eklenmez
    assert len(dlg._folders) == 2

    remove_buttons = [b for b in dlg.findChildren(QPushButton) if b.text() == "Kaldır" and "Belgeler" in b.accessibleName()]
    qtbot.mouseClick(remove_buttons[0], Qt.MouseButton.LeftButton)
    assert dlg._folders == [str(demo_root)]

    last = [b for b in dlg.findChildren(QPushButton) if b.text() == "Kaldır" and "Projeler" in b.accessibleName()]
    qtbot.mouseClick(last[-1], Qt.MouseButton.LeftButton)
    assert dlg._folders == [str(demo_root)]
    assert msgs[-1][1] == "Uyarı"


def test_missing_folder_is_flagged(qtbot, demo_root, tmp_path):
    from utils.settings import save_settings

    save_settings({"search_roots": [str(demo_root), str(tmp_path / "yok")], "tantivy_primary": False})
    d = SettingsDialog()
    qtbot.addWidget(d)
    texts = [lbl.text() for row in d.findChildren(_FolderRow) for lbl in row.findChildren(sd.QLabel)]
    assert any("(bulunamadı)" in t for t in texts)


def test_toggles_and_save_persist(qtbot, dlg):
    before = load_settings()
    for cb in (dlg._snippets_cb, dlg._fuzzy_cb, dlg._scheduled_cb):
        cb.click()
    dlg._scheduled_hour.setValue(5)
    dlg._exclude_edit.setPlainText("*.log\n\n  gizli  ")
    with qtbot.waitSignal(dlg.accepted, timeout=2000):
        qtbot.mouseClick(_button(dlg, "Kaydet"), Qt.MouseButton.LeftButton)
    after = load_settings()
    assert after["show_snippets"] != before["show_snippets"]
    assert after["fuzzy_search_enabled"] != before["fuzzy_search_enabled"]
    assert after["scheduled_reindex_enabled"] != before["scheduled_reindex_enabled"]
    assert after["scheduled_reindex_hour"] == 5
    assert after["exclude_patterns"] == ["*.log", "gizli"]


def test_cancel_close_and_escape_do_not_save(qtbot, demo_root):
    before = load_settings()
    for how in ("cancel", "close", "esc"):
        d = SettingsDialog()
        qtbot.addWidget(d)
        d.show()
        d._fuzzy_cb.click()
        with qtbot.waitSignal(d.rejected, timeout=2000):
            if how == "cancel":
                qtbot.mouseClick(_button(d, "İptal"), Qt.MouseButton.LeftButton)
            elif how == "close":
                qtbot.mouseClick(d.findChild(QToolButton), Qt.MouseButton.LeftButton)
            else:
                qtbot.keyClick(d, Qt.Key.Key_Escape)
    assert load_settings() == before


def test_rebuild_index_runs_and_reenables(qtbot, dlg, msgs):
    btn = _button(dlg, "Yeniden indeksle")
    qtbot.mouseClick(btn, Qt.MouseButton.LeftButton)
    assert not btn.isEnabled()
    qtbot.mouseClick(btn, Qt.MouseButton.LeftButton)  # devre dışıyken ikinci tık iş başlatmaz
    qtbot.waitUntil(lambda: btn.isEnabled(), timeout=10000)
    assert msgs and msgs[-1][0] == "information"
    assert get_index_stats()["count"] >= 5
    assert dlg._index_label.text().startswith("Son indeks:")


def test_close_during_rebuild_does_not_crash(qtbot, dlg, msgs):
    qtbot.mouseClick(_button(dlg, "Yeniden indeksle"), Qt.MouseButton.LeftButton)
    dlg.reject()
    assert dlg._index_worker is None or not dlg._index_worker.isRunning()


def test_clear_history(qtbot, demo_root):
    search_history.record_search("rapor", 3, 4)
    d = SettingsDialog()
    qtbot.addWidget(d)
    assert d._history_label.text().startswith("1 sorgu")
    qtbot.mouseClick(_button(d, "Temizle"), Qt.MouseButton.LeftButton)
    assert d._history_label.text().startswith("0 sorgu") and search_history.recent_queries() == []


def test_export_and_import_index(qtbot, dlg, tmp_path, monkeypatch, msgs):
    from utils import index_db

    index_db.build_index([Path(p) for p in dlg._folders])
    target = tmp_path / "yedek.db"
    monkeypatch.setattr(sd.QFileDialog, "getSaveFileName", lambda *a, **k: (str(target), ""))
    monkeypatch.setattr(sd.QFileDialog, "getOpenFileName", lambda *a, **k: (str(target), ""))
    qtbot.mouseClick(_button(dlg, "İndeksi dışa aktar"), Qt.MouseButton.LeftButton)
    assert target.is_file() and msgs[-1][1] == "Dışa aktarma"
    qtbot.mouseClick(_button(dlg, "İndeksi içe aktar"), Qt.MouseButton.LeftButton)
    assert msgs[-1][1] == "İçe aktarma"


def test_tray_menu_actions_and_status(qtbot):
    menu = TrayMenu()
    qtbot.addWidget(menu)
    texts = [a.text() for a in menu.actions() if a.text()]
    assert texts == ["Aramayı aç", "İndeks ayarları", "Yeniden indeksle", "Çıkış"]
    fired = []
    menu.open_search_action.triggered.connect(lambda: fired.append("open"))
    menu.reindex_action.triggered.connect(lambda: fired.append("reindex"))
    menu.open_search_action.trigger()
    menu.reindex_action.trigger()
    assert fired == ["open", "reindex"]
    menu.update_index_status("İndeks hatası", error=True)
    assert "İndeks hatası" in menu._status_label.text()
    assert "FTS5" in menu._index_info_label.text() or "TANTIVY" in menu._index_info_label.text()
