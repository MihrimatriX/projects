"""Ana pencere, menüler, kısayollar ve tüm diyaloglar — pytest-qt ile gerçek widget etkileşimi."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from PySide6.QtCore import QMimeData, QPoint, Qt, QTimer, QUrl
from PySide6.QtGui import QDropEvent
from PySide6.QtWidgets import QApplication, QCheckBox, QDialog, QLabel, QLineEdit, QPushButton

from tests.ui.conftest import make_dupes
from ui import main_window as mw
from ui.dialogs.delete_confirm_dialog import DeleteConfirmDialog
from ui.dialogs.group_detail_dialog import GroupDetailDialog
from ui.widgets.duplicate_group_widget import DuplicateGroupWidget
from utils import settings as settings_mod
from utils.duplicates import marked_for_deletion


_watchers: list[dict] = []


def on_modal(callback, delay: int = 80, tries: int = 60) -> list:
    """Sıradaki modal diyalog açılınca callback(dlg) çalıştırır; açılan diyalog adlarını döndürür."""
    seen: list = []
    state = {"alive": True}
    _watchers.append(state)

    def run(left=tries):
        if not state["alive"]:
            return
        dlg = QApplication.activeModalWidget()
        if dlg is None:
            if left:
                QTimer.singleShot(50, lambda: run(left - 1))
            return
        state["alive"] = False
        seen.append(type(dlg).__name__)
        callback(dlg)

    QTimer.singleShot(delay, run)
    return seen


@pytest.fixture(autouse=True)
def _stop_watchers():
    """Diyalog açılmadıysa bekleyen izleyici sonraki testin diyaloğunu yakalamasın."""
    yield
    for state in _watchers:
        state["alive"] = False
    _watchers.clear()


def press(qtbot, w, key, mods=Qt.KeyboardModifier.NoModifier):
    """Pencere kısayolu: modal diyalog kapandıktan sonra pencereyi yeniden etkinleştirip tuşa basar."""
    w.activateWindow()
    qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
    qtbot.keyClick(w, key, mods)


def close_dialog(dlg):
    dlg.reject() if isinstance(dlg, QDialog) else dlg.close()


@pytest.fixture
def msgs(monkeypatch):
    seen = []
    for kind in ("information", "warning", "critical"):
        monkeypatch.setattr(
            mw.QMessageBox, kind,
            lambda *a, k=kind, **kw: seen.append((k, a[2] if len(a) > 2 else "")) or mw.QMessageBox.StandardButton.Yes,
        )
    return seen


def scan(qtbot, w, via="button"):
    if via == "button":
        qtbot.mouseClick(w.scan_btn, Qt.MouseButton.LeftButton)
    else:
        press(qtbot, w, Qt.Key.Key_F5)
    qtbot.waitUntil(lambda: w._worker is not None and not w._worker.isRunning() and w.scan_btn.isEnabled(), timeout=10000)
    qtbot.wait(20)


def test_empty_state_add_folder_and_remove(qtbot, make_window, tmp_path, monkeypatch):
    w = make_window()
    assert w.page_stack.currentWidget() is w.empty_state
    assert w.scan_status.text() == "Kök klasör ekleyin"
    folder = tmp_path / "Belgeler"
    folder.mkdir()
    monkeypatch.setattr(mw.QFileDialog, "getExistingDirectory", lambda *a, **k: str(folder))
    browse = next(b for b in w.empty_state.findChildren(QPushButton) if "Klasör seç" in b.text())
    qtbot.mouseClick(browse, Qt.MouseButton.LeftButton)
    assert w._roots() == [str(folder)] and w.page_stack.currentIndex() == 1
    assert w._store.settings.roots == [str(folder)]  # kalıcı

    press(qtbot, w, Qt.Key.Key_O, Qt.KeyboardModifier.ControlModifier)  # aynı klasör iki kez eklenmez
    assert w._roots() == [str(folder)]

    w.roots_list.setCurrentRow(0)
    assert w.remove_root_btn.isEnabled()
    qtbot.mouseClick(w.remove_root_btn, Qt.MouseButton.LeftButton)
    assert w._roots() == [] and w.page_stack.currentWidget() is w.empty_state


def test_remove_root_with_delete_key_and_context_menu(qtbot, make_window, tmp_path):
    a, b = tmp_path / "A", tmp_path / "B"
    a.mkdir(), b.mkdir()
    w = make_window(initial_roots=[str(a), str(b)])
    w.roots_list.setFocus()
    w.roots_list.setCurrentRow(0)
    qtbot.waitUntil(w.roots_list.hasFocus, timeout=2000)
    qtbot.keyClick(w.roots_list, Qt.Key.Key_Delete)
    assert w._roots() == [str(b)]
    menu = w._build_roots_menu(str(b))
    assert [x.text().split("\t")[0] for x in menu.actions()] == ["Explorer'da aç", "Listeden kaldır"]
    w.roots_list.setCurrentRow(0)
    menu.actions()[1].trigger()
    assert w._roots() == []


def test_drag_and_drop_folder(qtbot, make_window, tmp_path):
    w = make_window()
    folder = tmp_path / "Surukle"
    folder.mkdir()
    mime = QMimeData()
    mime.setUrls([QUrl.fromLocalFile(str(folder)), QUrl.fromLocalFile(str(tmp_path / "yok.txt"))])
    ev = QDropEvent(QPoint(10, 10).toPointF(), Qt.DropAction.CopyAction, mime, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier)
    w.dropEvent(ev)
    assert [Path(r) for r in w._roots()] == [folder]  # var olmayan yol eklenmez


def test_scan_shows_cards_and_marks(qtbot, make_window, tmp_path, msgs):
    root = make_dupes(tmp_path / "demo", 3)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    assert len(w._all_groups) == 3
    assert w.results_stack.currentWidget() is w.groups_scroll
    assert "3 grup" in w.scan_status.text() and w.savings_banner.isVisible()
    assert w.delete_btn.isEnabled()  # öneri kopyaları işaretler
    assert w.selection_info.text().startswith("<b>3</b>")

    cards = w.groups_scroll.findChildren(DuplicateGroupWidget)
    card = cards[0]
    assert card._body.isVisible()  # ≤8 grupta ilk kart açık
    qtbot.mouseClick(card._head, Qt.MouseButton.LeftButton)
    assert not card._body.isVisible()
    card._head.setFocus()
    qtbot.keyClick(card._head, Qt.Key.Key_Space)
    assert card._body.isVisible()

    cb = next(c for c in card._checkboxes if c.isEnabled())
    tag_texts = lambda: [t.text() for t in card._tags]  # noqa: E731
    assert "Silinecek" in tag_texts()
    qtbot.mouseClick(cb, Qt.MouseButton.LeftButton)
    assert "Silinecek" not in tag_texts() and "Kopya" in tag_texts()
    assert w.selection_info.text().startswith("<b>2</b>")
    assert all(c.accessibleName() for c in card._checkboxes)


def test_f5_shortcut_filter_sort_and_ctrl_f(qtbot, make_window, tmp_path, store):
    root = make_dupes(tmp_path / "demo", 4)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w, via="f5")
    assert len(w._all_groups) == 4

    press(qtbot, w, Qt.Key.Key_F, Qt.KeyboardModifier.ControlModifier)
    qtbot.waitUntil(w.filter_input.hasFocus, timeout=2000)
    qtbot.keyClicks(w.filter_input, "dosya_002")
    assert w.results_info.text().startswith("1/1 grup")
    w.filter_input.clear()
    assert w.results_info.text().startswith("4/4 grup")

    w.sort_combo.setCurrentIndex(w.sort_combo.findData("path"))
    assert store.settings.sort_mode == "path"


def test_action_buttons_and_tools_menu(qtbot, make_window, tmp_path, msgs):
    w = make_window()
    w._apply_strategy()  # boş sayfada eylem çubuğu görünmez; menü eylemi aynı yolu kullanır
    assert msgs[-1] == ("information", "Önce tarama yapın.")

    root = make_dupes(tmp_path / "demo", 2, copies=3)
    w.apply_external_handoff({"roots": [str(root)], "auto_scan": False})
    assert w._roots() == [str(root)]
    scan(qtbot, w)
    acts = {a.text(): a for m in w.menuBar().actions() for a in m.menu().actions()}
    acts["İşaretleri temizle"].trigger()
    assert marked_for_deletion(w._all_groups) == [] and not w.delete_btn.isEnabled()
    qtbot.mouseClick(w.select_all_btn, Qt.MouseButton.LeftButton)
    assert len(marked_for_deletion(w._all_groups)) == 4  # 2 grup x 2 kopya (asıl hariç)
    acts["İşaretleri tersine çevir"].trigger()
    assert marked_for_deletion(w._all_groups) == []
    qtbot.mouseClick(w.strategy_btn, Qt.MouseButton.LeftButton)
    assert len(marked_for_deletion(w._all_groups)) == 4


def test_delete_to_trash_flow(qtbot, make_window, tmp_path, msgs, monkeypatch):
    root = make_dupes(tmp_path / "demo", 2)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    trashed = []

    def fake_trash(paths):  # gerçek Geri Dönüşüm Kutusu'na dokunma
        for p in paths:
            Path(p).unlink()
            trashed.append(p)
        return len(paths), []

    monkeypatch.setattr(mw, "move_to_trash", fake_trash)
    seen = on_modal(lambda d: d.accept())
    press(qtbot, w, Qt.Key.Key_Delete)
    assert seen == ["DeleteConfirmDialog"]
    assert len(trashed) == 2 and w._all_groups == []
    assert ("information", "2 dosya işlendi.") in msgs
    assert not w.delete_btn.isEnabled()


def test_delete_cancel_keeps_files(qtbot, make_window, tmp_path, monkeypatch):
    root = make_dupes(tmp_path / "demo", 1)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    monkeypatch.setattr(mw, "move_to_trash", lambda p: pytest.fail("iptalde silinmemeli"))
    seen = on_modal(close_dialog)
    qtbot.mouseClick(w.delete_btn, Qt.MouseButton.LeftButton)
    assert seen == ["DeleteConfirmDialog"] and len(w._all_groups) == 1


def test_delete_confirm_dialog_permanent_toggle(qtbot):
    dlg = DeleteConfirmDialog(["C:/a.txt"] * 45, 2048)
    qtbot.addWidget(dlg)
    dlg.show()
    qtbot.waitExposed(dlg)
    assert dlg.list.count() == 41 and "çöp kutusuna" in dlg.summary.text()
    # Gösterge kutusuna tıkla (geniş satırda metnin sağındaki boşluk tıklanabilir alan değil)
    qtbot.mouseClick(dlg.permanent_cb, Qt.MouseButton.LeftButton, pos=QPoint(8, dlg.permanent_cb.height() // 2))
    assert dlg.permanent_delete and dlg.ok_btn.text() == "Kalıcı olarak sil"
    assert "kalıcı olarak silinecek" in dlg.summary.text()
    dlg.permanent_cb.click()
    assert dlg.ok_btn.text() == "Çöp kutusuna taşı"


def test_exports_via_menu_and_shortcuts(qtbot, make_window, tmp_path, monkeypatch, msgs):
    root = make_dupes(tmp_path / "demo", 2)
    w = make_window(initial_roots=[str(root)])
    w._export_json()
    assert msgs[-1] == ("information", "Dışa aktarılacak sonuç yok.")
    scan(qtbot, w)
    out = tmp_path / "rapor"
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: (str(out), ""))
    press(qtbot, w, Qt.Key.Key_E, Qt.KeyboardModifier.ControlModifier)
    press(qtbot, w, Qt.Key.Key_E, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier)
    press(qtbot, w, Qt.Key.Key_H, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier)
    for ext in ("json", "csv", "html"):
        assert (tmp_path / f"rapor.{ext}").stat().st_size > 0, ext
    assert w._store.settings.last_export_dir == str(tmp_path)


def test_session_save_and_load(qtbot, make_window, tmp_path, monkeypatch, msgs):
    root = make_dupes(tmp_path / "demo", 2)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    sess = tmp_path / "oturum.json"
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: (str(sess), ""))
    monkeypatch.setattr(mw.QFileDialog, "getOpenFileName", lambda *a, **k: (str(sess), ""))
    acts = {a.text(): a for m in w.menuBar().actions() for a in m.menu().actions()}
    acts["Oturumu kaydet…"].trigger()
    assert sess.is_file()
    w._all_groups = []
    w._render_groups()
    acts["Oturumu yükle…"].trigger()
    assert len(w._all_groups) == 2 and "Oturum yüklendi" in w.statusBar().currentMessage()

    sess.write_text("{bozuk", encoding="utf-8")
    acts["Oturumu yükle…"].trigger()
    assert msgs[-1][0] == "critical"


def test_history_cache_help_about_dialogs(qtbot, make_window, tmp_path, msgs):
    root = make_dupes(tmp_path / "demo", 1)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    acts = {a.text(): a for m in w.menuBar().actions() for a in m.menu().actions()}

    texts = []
    seen = on_modal(lambda d: (texts.append(d.list.item(0).text()), d.accept()))
    acts["Tarama geçmişi"].trigger()
    assert seen == ["ScanHistoryDialog"] and "1 grup" in texts[0]

    acts["Önbelleği temizle"].trigger()
    assert msgs[-1] == ("information", "Tarama önbelleği temizlendi.")
    acts["Önbelleği temizle"].trigger()
    assert msgs[-1] == ("information", "Önbellek zaten boş.")

    seen = on_modal(close_dialog)
    press(qtbot, w, Qt.Key.Key_F1)
    assert seen == ["HelpDialog"]
    seen = on_modal(lambda d: next(b for b in d.findChildren(QPushButton) if b.text() == "Kapat").click())
    acts["Hakkında"].trigger()
    assert seen == ["AboutDialog"]


def test_settings_dialog_roundtrip(qtbot, make_window, tmp_path, store):
    root = make_dupes(tmp_path / "demo", 2)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)

    def edit(dlg):
        dlg.min_size.setValue(2)
        dlg.strategy.setCurrentIndex(dlg.strategy.findData("shortest"))
        qtbot.keyClicks(dlg.protected, str(root / "Yedek"))
        dlg.skip_hidden.click()
        dlg.accept()

    seen = on_modal(edit)
    press(qtbot, w, Qt.Key.Key_Comma, Qt.KeyboardModifier.ControlModifier)
    assert seen == ["SettingsDialog"]
    s = store.settings
    assert (s.min_size_kb, s.keep_strategy, s.skip_hidden) == (2, "shortest", False)
    saved = json.loads(settings_mod.SETTINGS_PATH.read_text(encoding="utf-8"))
    assert saved["protected_folders"] == str(root / "Yedek")
    # Korunan klasör değişince mevcut işaretler yenilenir: Yedek'teki kopyalar silinmeye işaretlenmez
    assert not any("Yedek" in p for p in marked_for_deletion(w._all_groups))

    seen = on_modal(close_dialog)  # İptal: hiçbir şey değişmez
    acts = {a.text(): a for m in w.menuBar().actions() for a in m.menu().actions()}
    acts["Ayarlar…"].trigger()
    assert seen == ["SettingsDialog"] and store.settings.min_size_kb == 2


def test_load_more_and_compact_list(qtbot, make_window, tmp_path, store):
    root = make_dupes(tmp_path / "demo", 5)
    store.settings.results_page_size = 2
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    assert w.results_info.text().startswith("2/5 grup") and w.load_more_btn.isVisible()
    qtbot.mouseClick(w.load_more_btn, Qt.MouseButton.LeftButton)
    assert w.results_info.text().startswith("4/5 grup")

    store.settings.compact_list_threshold = 3
    w._render_groups()
    assert w.results_stack.currentWidget() is w.compact_list
    view = w.compact_list
    view.setFocus()
    view.setCurrentIndex(view.model().index(0, 0))
    seen = on_modal(close_dialog)
    qtbot.keyClick(view, Qt.Key.Key_Return)  # Enter grup detayını açar (eskiden yalnız çift tık)
    assert seen == ["GroupDetailDialog"]


def test_tree_view_for_many_groups(qtbot, make_window, tmp_path):
    root = make_dupes(tmp_path / "demo", 82)
    w = make_window(initial_roots=[str(root)])
    scan(qtbot, w)
    assert w.results_stack.currentWidget() is w.results_tree
    tree = w.results_tree
    top = tree.topLevelItem(0)
    child = next(top.child(i) for i in range(top.childCount()) if top.child(i).flags() & Qt.ItemFlag.ItemIsUserCheckable)
    before = len(marked_for_deletion(w._all_groups))
    child.setCheckState(0, Qt.CheckState.Unchecked)
    assert len(marked_for_deletion(w._all_groups)) == before - 1


def test_group_detail_escape_applies_marks(qtbot, tmp_path):
    from utils.models import DuplicateFile, DuplicateGroup

    g = DuplicateGroup("ab" * 32, 10, [DuplicateFile("C:/a", 10, 1, is_keeper=True), DuplicateFile("C:/b", 10, 2, marked_for_delete=True)])
    dlg = GroupDetailDialog(g)
    qtbot.addWidget(dlg)
    dlg.show()
    box = [c for c in dlg.findChildren(QCheckBox) if c.isEnabled()][0]
    assert box.accessibleName()
    box.click()
    qtbot.keyClick(dlg, Qt.Key.Key_Escape)
    assert g.files[1].marked_for_delete is False


def test_scan_errors_and_cancel(qtbot, make_window, tmp_path, msgs):
    w = make_window()
    w._start_scan()
    assert msgs[-1] == ("warning", "En az bir tarama klasörü ekleyin.")
    gone = tmp_path / "silinecek"
    gone.mkdir()
    w._add_roots([str(gone)])
    gone.rmdir()
    scan(qtbot, w)
    assert w.scan_btn.isEnabled()
    press(qtbot, w, Qt.Key.Key_Escape)  # çalışan tarama yokken Esc zararsız
    w._on_scan_cancelled()
    assert w.scan_status.text().startswith("Taramaya hazır")


def test_external_handoff_and_close_saves_size(qtbot, make_window, tmp_path, store):
    w = make_window()
    w.apply_external_handoff({"action": "show"})
    assert w.statusBar().currentMessage() == "Pencere öne getirildi"
    w.resize(1300, 700)
    size = (w.width(), w.height())
    w.close()
    assert (store.settings.window_width, store.settings.window_height) == size


def test_accessible_names_on_inputs(make_window):
    w = make_window()
    for widget in (w.filter_input, w.sort_combo, w.roots_list):
        assert widget.accessibleName()
    assert all(isinstance(x, QLineEdit) or x.text() for x in w.findChildren(QPushButton) if x.isVisible())
    assert not [lbl for lbl in w.empty_state.findChildren(QLabel) if "IPC" in lbl.text()]
