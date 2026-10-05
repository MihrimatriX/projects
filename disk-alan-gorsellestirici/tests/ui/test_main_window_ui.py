"""Ana pencere, menüler, kısayollar, grafikler (fare + klavye), kenar paneli ve tüm diyaloglar."""
from __future__ import annotations

import json

import pytest
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QContextMenuEvent
from PySide6.QtWidgets import QApplication, QDialog, QMenu, QMessageBox

from ui import main_window as mw
from ui.dialogs import duplicates_dialog as dd
from ui.dialogs.about_dialog import AboutDialog
from ui.dialogs.duplicates_dialog import DuplicatesDialog
from ui.dialogs.help_dialog import HelpDialog
from ui.dialogs.settings_dialog import SettingsDialog
from ui.dialogs.welcome_dialog import WelcomeDialog

_watchers: list[dict] = []


class Msgs(list):
    answer: dict


def on_modal(callback, *, popup: bool = False, delay: int = 80, tries: int = 60) -> list:
    """Sıradaki modal diyalog (ya da açılır menü) açılınca callback(widget) çalıştırır."""
    seen: list = []
    state = {"alive": True}
    _watchers.append(state)

    def run(left=tries):
        if not state["alive"]:
            return
        dlg = QApplication.activePopupWidget() if popup else QApplication.activeModalWidget()
        if dlg is None:
            if left:
                QTimer.singleShot(50, lambda: run(left - 1))
            return
        state["alive"] = False
        seen.append(type(dlg).__name__)
        callback(dlg)

    QTimer.singleShot(delay, run)
    return seen


def pick_menu(text: str) -> list:
    """Açılan QMenu'de metni `text` ile başlayan eylemi tetikler."""

    def choose(menu: QMenu):
        action = next(a for a in menu.actions() if a.text().startswith(text))
        menu.close()
        action.trigger()

    return on_modal(choose, popup=True)


@pytest.fixture(autouse=True)
def _stop_watchers():
    yield
    for state in _watchers:
        state["alive"] = False
    _watchers.clear()


@pytest.fixture
def msgs(monkeypatch):
    """QMessageBox çağrılarını kaydeder; question için verilen yanıtı döndürür."""
    seen = Msgs()
    answer = {"value": QMessageBox.StandardButton.Yes}
    for kind in ("information", "warning", "critical"):
        monkeypatch.setattr(
            mw.QMessageBox, kind,
            lambda *a, k=kind, **kw: seen.append((k, a[2] if len(a) > 2 else "")) or QMessageBox.StandardButton.Ok,
        )
    monkeypatch.setattr(
        mw.QMessageBox, "question", lambda *a, **kw: seen.append(("question", a[2])) or answer["value"]
    )
    seen.answer = answer
    return seen


def press(qtbot, w, key, mods=Qt.KeyboardModifier.NoModifier):
    """Pencere kısayolu: modal kapandıktan sonra pencereyi yeniden etkinleştirip tuşa basar."""
    w.activateWindow()
    qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
    qtbot.keyClick(w, key, mods)


def wait_scan(qtbot, w):
    qtbot.waitUntil(lambda: not w._scanning and w._root is not None, timeout=15000)


def scanned(qtbot, make_window, tree):
    w = make_window(tree)
    qtbot.mouseClick(w.scan_btn, Qt.MouseButton.LeftButton)
    wait_scan(qtbot, w)
    return w


def crumbs(w):
    QApplication.processEvents()  # yeni düğmeler kuyruklu show ile görünür olur
    return [b for b in w.breadcrumb.findChildren(type(w.scan_btn)) if not b.isHidden()]


def chart(w):
    return w.chart_stack.currentWidget()


def select_segment(qtbot, c, name: str):
    """Klavyeyle (→) adı `name` olan segmente gelir."""
    c.setFocus()
    for _ in range(len(c._kb_items()) + 1):
        qtbot.keyClick(c, Qt.Key.Key_Right)
        if c.selected_node() and c.selected_node().name == name:
            return c.selected_node()
    raise AssertionError(f"segment yok: {name}")


# --- Boş durum -----------------------------------------------------------------------------

def test_empty_state_and_guards(qtbot, make_window, msgs):
    w = make_window()
    assert w.scan_btn.text() == "Tara"
    assert w.statusBar().currentMessage().startswith("Hazır")
    assert w.breadcrumb.findChild(type(w.scan_status)).text() == "Henüz tarama yok"
    assert not w.dup_chip.isVisible()
    press(qtbot, w, Qt.Key.Key_E, Qt.KeyboardModifier.ControlModifier)
    press(qtbot, w, Qt.Key.Key_D, Qt.KeyboardModifier.ControlModifier)
    assert [k for k, _ in msgs] == ["information", "information"]
    assert "Önce bir tarama" in msgs[0][1]
    # Tarama yokken Esc / Backspace / Alt+Home zararsız
    for key, mods in ((Qt.Key.Key_Escape, Qt.KeyboardModifier.NoModifier),
                      (Qt.Key.Key_Backspace, Qt.KeyboardModifier.NoModifier),
                      (Qt.Key.Key_Home, Qt.KeyboardModifier.AltModifier)):
        press(qtbot, w, key, mods)
    assert w._root is None


# --- Tarama ---------------------------------------------------------------------------------

def test_scan_button_fills_charts_sidebar_and_chip(qtbot, make_window, tree, store):
    w = scanned(qtbot, make_window, tree)
    assert w._root.name == "Ornek"
    assert w.scan_btn.text() == "Tara"
    assert "Tarama tamam" in w.scan_status.text()
    assert w.dup_chip.isVisible() and w.dup_chip.text() == "1 tekrar adayı"
    names = [w.sidebar.large_list.item(i).text() for i in range(w.sidebar.large_list.count())]
    assert any(n.startswith("film.mkv") for n in names)
    assert w.sidebar.cleanup_card.isVisible()
    assert w.sidebar.cleanup_btn.text() == "Temizle: node_modules…"
    assert w.sidebar.timeline._labels[0].text() == "Bugün"
    assert {n.name for n in (s.node for s in w.sunburst._segments)} >= {"Videolar", "Yedek", "node_modules"}
    assert store.settings.recent_roots[0] == str(tree)
    assert chart(w).hasFocus()  # tarama sonrası grafik klavyeyle kullanılabilir


def test_f5_uses_cache_and_shift_f5_rescans(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    (tree / "Belgeler" / "yeni.txt").write_bytes(b"x" * 5000)
    press(qtbot, w, Qt.Key.Key_F5, Qt.KeyboardModifier.ShiftModifier)
    w._root = None
    wait_scan(qtbot, w)
    belgeler = next(c for c in w._root.children if c.name == "Belgeler")
    assert belgeler.file_count == 2
    w._root = None
    press(qtbot, w, Qt.Key.Key_F5)
    wait_scan(qtbot, w)
    assert w._root.name == "Ornek"


def test_ctrl_o_picks_folder_and_cancel_does_nothing(qtbot, make_window, tree, monkeypatch):
    w = make_window()
    monkeypatch.setattr(mw.QFileDialog, "getExistingDirectory", lambda *a, **k: "")
    press(qtbot, w, Qt.Key.Key_O, Qt.KeyboardModifier.ControlModifier)
    assert not w._scanning and w._root is None
    monkeypatch.setattr(mw.QFileDialog, "getExistingDirectory", lambda *a, **k: str(tree))
    press(qtbot, w, Qt.Key.Key_O, Qt.KeyboardModifier.ControlModifier)
    wait_scan(qtbot, w)
    assert w._root.name == "Ornek"
    # Araç çubuğu düğmesi de aynı akış
    w._root = None
    qtbot.mouseClick(w.pick_btn, Qt.MouseButton.LeftButton)
    wait_scan(qtbot, w)


def test_esc_cancels_scan_and_banner_rescans(qtbot, make_window, tree):
    w = make_window(tree)
    w._start_scan(use_cache=False)
    assert w._scanning and w.scan_btn.text() == "İptal"
    press(qtbot, w, Qt.Key.Key_Escape)
    assert not w._scanning
    assert w.scan_status.text() == "İptal edildi"
    assert w.state_banner._action.isVisible() and w.state_banner._action.text() == "Yeniden tara"
    qtbot.mouseClick(w.state_banner._action, Qt.MouseButton.LeftButton)
    wait_scan(qtbot, w)


def test_scan_button_toggles_to_cancel(qtbot, make_window, tree):
    w = make_window(tree)
    w._start_scan(use_cache=False)
    qtbot.mouseClick(w.scan_btn, Qt.MouseButton.LeftButton)
    assert not w._scanning and w.scan_btn.text() == "Tara"


def test_missing_root_shows_error(qtbot, make_window, tmp_path, msgs):
    w = make_window(tmp_path / "yok")
    qtbot.mouseClick(w.scan_btn, Qt.MouseButton.LeftButton)
    qtbot.waitUntil(lambda: not w._scanning, timeout=5000)
    assert msgs and msgs[-1][0] == "warning" and "bulunamadı" in msgs[-1][1]
    assert w.state_banner.isVisible()


def test_depth_chip_menu(qtbot, make_window, store):
    w = make_window()
    for i, text in enumerate(("Derinlik: 3", "Derinlik: 5", "Derinlik: ∞")):
        w.depth_chip.menu().actions()[i].trigger()
        assert w.depth_chip.text() == text and store.settings.depth_index == i


# --- Grafikler ------------------------------------------------------------------------------

def test_keyboard_drill_up_and_root(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    c = chart(w)
    node = select_segment(qtbot, c, "Videolar")
    assert w.statusBar().currentMessage().startswith("Videolar")
    qtbot.keyClick(c, Qt.Key.Key_Return)
    assert w._focus.name == "Videolar"
    assert [b.text() for b in crumbs(w)] == ["Ornek", "Videolar"]
    press(qtbot, w, Qt.Key.Key_Backspace)
    assert w._focus is w._root
    w._drill_to(node)
    press(qtbot, w, Qt.Key.Key_Home, Qt.KeyboardModifier.AltModifier)
    assert w._focus is w._root
    w._drill_to(node)
    press(qtbot, w, Qt.Key.Key_Escape)
    assert w._focus is w._root


def test_left_arrow_wraps_and_enter_on_file_is_ignored(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    c = chart(w)
    c.setFocus()
    qtbot.keyClick(c, Qt.Key.Key_Left)
    assert c.selected_node() is c._kb_items()[-1].node
    w._drill_to(next(n for n in w._root.children if n.name == "Videolar"))
    select_segment(qtbot, c, "film.mkv")
    qtbot.keyClick(c, Qt.Key.Key_Return)
    assert w._focus.name == "Videolar"


@pytest.mark.parametrize("view", [0, 1])
def test_mouse_click_drills_in_both_views(qtbot, make_window, tree, view):
    w = scanned(qtbot, make_window, tree)
    w._set_view(view)
    c = chart(w)
    qtbot.waitExposed(c)
    seg = next(s for s in c._kb_items() if s.node.name == "Videolar")
    pos = c._kb_center(seg).toPoint()
    qtbot.mouseMove(c, pos)
    qtbot.mouseClick(c, Qt.MouseButton.LeftButton, pos=pos)
    assert w._focus.name == "Videolar"


def test_breadcrumb_navigates_up(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    w._drill_to(next(n for n in w._root.children if n.name == "Videolar"))
    root_btn = next(b for b in crumbs(w) if b.text() == "Ornek")
    qtbot.mouseClick(root_btn, Qt.MouseButton.LeftButton)
    assert w._focus is w._root


def test_empty_folder_shows_empty_state(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    bos = next(n for n in w._root.children if n.name == "Bos")
    w._navigate_to(bos)
    assert w.sunburst._segments == [] and w.treemap._rects == []
    w.sunburst.grab()  # boş durum çizimi hata vermemeli
    w._set_view(1)
    w.treemap.grab()


def test_context_menu_actions(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    c = chart(w)

    def open_menu(name, item):
        seg = next(s for s in c._kb_items() if s.node.name == name)
        pos = c._kb_center(seg).toPoint()
        seen = pick_menu(item)
        QApplication.sendEvent(c, QContextMenuEvent(QContextMenuEvent.Reason.Mouse, pos, c.mapToGlobal(pos)))
        qtbot.waitUntil(lambda: bool(seen), timeout=3000)

    open_menu("Videolar", "Explorer'da göster")
    assert fakes["reveal"][-1].endswith("Videolar")
    open_menu("Videolar", "İçine gir")
    assert w._focus.name == "Videolar"
    w._go_root()
    open_menu("Yedek", "Burayı tara")
    wait_scan(qtbot, w)
    assert w._root.name == "Yedek"


def test_shift_f10_opens_context_menu_and_trash(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    c = chart(w)
    select_segment(qtbot, c, "node_modules")
    seen = pick_menu("Çöpe taşı")
    qtbot.keyClick(c, Qt.Key.Key_F10, Qt.KeyboardModifier.ShiftModifier)
    qtbot.waitUntil(lambda: bool(fakes["trash"]), timeout=3000)
    assert seen == ["QMenu"]
    assert not (tree / "node_modules").exists()
    assert "node_modules" not in {n.name for n in w._root.children}


def test_delete_key_asks_and_respects_no(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    c = chart(w)
    select_segment(qtbot, c, "Yedek")
    msgs.answer["value"] = QMessageBox.StandardButton.No
    qtbot.keyClick(c, Qt.Key.Key_Delete)
    assert msgs[-1][0] == "question" and (tree / "Yedek").exists()
    msgs.answer["value"] = QMessageBox.StandardButton.Yes
    qtbot.keyClick(c, Qt.Key.Key_Delete)
    assert not (tree / "Yedek").exists()
    assert not w.dup_chip.isVisible()  # tek kopya kalınca aday da düşer
    assert "Çöpe taşındı" in w.statusBar().currentMessage()


def test_view_toggle_buttons_and_shortcuts(qtbot, make_window, store):
    w = make_window()
    press(qtbot, w, Qt.Key.Key_2, Qt.KeyboardModifier.ControlModifier)
    assert w.chart_stack.currentIndex() == 1 and store.settings.view_index == 1
    press(qtbot, w, Qt.Key.Key_1, Qt.KeyboardModifier.ControlModifier)
    assert w.chart_stack.currentIndex() == 0
    qtbot.mouseClick(w.treemap_btn, Qt.MouseButton.LeftButton)
    assert w.chart_stack.currentIndex() == 1 and w.treemap_btn.objectName() == "ViewToggleActive"
    qtbot.mouseClick(w.sunburst_btn, Qt.MouseButton.LeftButton)
    assert w.chart_stack.currentIndex() == 0


def test_sidebar_toggle(qtbot, make_window):
    w = make_window()
    assert w.sidebar.isVisible()
    qtbot.mouseClick(w.sidebar_btn, Qt.MouseButton.LeftButton)
    assert not w.sidebar.isVisible()
    press(qtbot, w, Qt.Key.Key_B, Qt.KeyboardModifier.ControlModifier)
    assert w.sidebar.isVisible()
    assert w.sidebar_btn.accessibleName()


# --- Kenar paneli ---------------------------------------------------------------------------

def test_large_files_list_click_activate_menu_delete(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    lst = w.sidebar.large_list
    item = next(lst.item(i) for i in range(lst.count()) if lst.item(i).text().startswith("film.mkv"))
    rect = lst.visualItemRect(item)
    qtbot.mouseClick(lst.viewport(), Qt.MouseButton.LeftButton, pos=rect.center())
    assert fakes["reveal"] == []  # tek tık Explorer açmaz
    qtbot.mouseDClick(lst.viewport(), Qt.MouseButton.LeftButton, pos=rect.center())
    assert fakes["reveal"] and fakes["reveal"][-1].endswith("film.mkv")
    lst.setCurrentItem(item)
    lst.setFocus()
    qtbot.keyClick(lst, Qt.Key.Key_Return)
    assert len(fakes["reveal"]) >= 2
    seen = pick_menu("Explorer'da göster")
    lst.customContextMenuRequested.emit(rect.center())
    qtbot.waitUntil(lambda: bool(seen), timeout=3000)
    msgs.answer["value"] = QMessageBox.StandardButton.Yes
    qtbot.keyClick(lst, Qt.Key.Key_Delete)
    assert not (tree / "Videolar" / "film.mkv").exists()
    assert not any(lst.item(i).text().startswith("film.mkv") for i in range(lst.count()))


def test_large_files_context_menu_trash(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    lst = w.sidebar.large_list
    item = lst.item(0)
    seen = pick_menu("Çöpe taşı")
    lst.customContextMenuRequested.emit(lst.visualItemRect(item).center())
    qtbot.waitUntil(lambda: bool(fakes["trash"]), timeout=3000)
    assert seen and fakes["trash"][0].endswith("film.mkv")


def test_cleanup_button_trashes_suggestion(qtbot, make_window, tree, fakes, msgs):
    w = scanned(qtbot, make_window, tree)
    qtbot.mouseClick(w.sidebar.cleanup_btn, Qt.MouseButton.LeftButton)
    assert msgs[-1][0] == "question" and "node_modules" in msgs[-1][1]
    assert not (tree / "node_modules").exists()
    assert not w.sidebar.cleanup_card.isVisible()


def test_timeline_snapshots(qtbot, make_window, tree):
    w = scanned(qtbot, make_window, tree)
    (tree / "Belgeler" / "ek.bin").write_bytes(b"\0" * 300_000)
    w._start_scan(use_cache=False)
    w._root = None
    wait_scan(qtbot, w)
    tl = w.sidebar.timeline
    assert [b.isEnabled() for b in tl._buttons] == [True, True, False, False]
    assert tl._labels[1].text() == "Bugün"
    assert "Tarama" in tl._buttons[0].accessibleName()
    qtbot.mouseClick(tl._buttons[0], Qt.MouseButton.LeftButton)
    assert w.statusBar().currentMessage().startswith("Zaman makinesi")
    assert tl._active == 0


# --- Menüler, dışa aktarma ------------------------------------------------------------------

@pytest.mark.parametrize("ext", ["png", "svg", "json", "csv", "html"])
def test_export_formats(qtbot, make_window, tree, tmp_path, monkeypatch, ext):
    w = scanned(qtbot, make_window, tree)
    dest = tmp_path / f"rapor.{ext}"
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: (str(dest), ""))
    press(qtbot, w, Qt.Key.Key_E, Qt.KeyboardModifier.ControlModifier)
    assert dest.is_file() and dest.stat().st_size > 0
    if ext == "json":
        assert json.loads(dest.read_text(encoding="utf-8"))["root"]["name"] == "Ornek"
    if ext == "html":
        assert dest.with_suffix(".png").is_file()
    assert "Dışa aktarıldı" in w.statusBar().currentMessage()


def test_export_cancel_writes_nothing(qtbot, make_window, tree, monkeypatch):
    w = scanned(qtbot, make_window, tree)
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: ("", ""))
    w._export_menu()
    assert "Dışa aktarıldı" not in w.statusBar().currentMessage()


def test_recent_folders_menu(qtbot, make_window, tree, tmp_path, store, msgs):
    w = make_window()
    w.recent_menu.aboutToShow.emit()
    assert [a.text() for a in w.recent_menu.actions()] == ["(henüz yok)"]
    gone = tmp_path / "silindi"
    store.settings.recent_roots = [str(tree), str(gone)]
    w.recent_menu.aboutToShow.emit()
    texts = [a.text() for a in w.recent_menu.actions()]
    assert texts[:2] == [str(tree), str(gone)] and texts[-1] == "Listeyi temizle"
    w.recent_menu.actions()[1].trigger()
    assert msgs[-1][0] == "warning" and str(gone) not in store.settings.recent_roots
    w.recent_menu.aboutToShow.emit()
    w.recent_menu.actions()[0].trigger()
    wait_scan(qtbot, w)
    assert w._root.name == "Ornek"
    w.recent_menu.aboutToShow.emit()
    w.recent_menu.actions()[-1].trigger()
    assert store.settings.recent_roots == []


# --- Diyaloglar -----------------------------------------------------------------------------

def test_duplicates_dialog_and_bridge(qtbot, make_window, tree, monkeypatch):
    w = scanned(qtbot, make_window, tree)
    sent, revealed = [], []
    monkeypatch.setattr(dd, "open_in_tekrarlanan_bulucu", lambda g: sent.append(g) or (True, "2 klasör çalışan örneğe IPC ile aktarıldı."))
    monkeypatch.setattr(dd, "reveal_in_explorer", lambda p: revealed.append(p))
    state = {}

    def use(dlg: DuplicatesDialog):
        state["title"] = dlg.windowTitle()
        lst = dlg.list
        state["rows"] = [lst.item(i).text().strip() for i in range(lst.count())]
        lst.setCurrentRow(1)
        qtbot.mouseClick(dlg.open_btn, Qt.MouseButton.LeftButton)
        qtbot.keyClick(lst, Qt.Key.Key_Return)
        qtbot.mouseClick(dlg.deep_btn, Qt.MouseButton.LeftButton)  # IPC başarılı → kapanır

    seen = on_modal(use)
    qtbot.mouseClick(w.dup_chip, Qt.MouseButton.LeftButton)
    assert seen == ["DuplicatesDialog"]
    assert state["title"] == "Tekrar adayları"
    assert any(r.endswith("klip.mp4") for r in state["rows"]) and any(r.endswith("klip-kopya.mp4") for r in state["rows"])
    assert len(revealed) == 2 and sent and sent[0][0].count == 2


def test_duplicates_dialog_bridge_failure_warns(qtbot, make_window, tree, monkeypatch):
    w = scanned(qtbot, make_window, tree)
    warned = []
    monkeypatch.setattr(dd, "open_in_tekrarlanan_bulucu", lambda g: (False, "bulunamadı"))
    from PySide6 import QtWidgets

    monkeypatch.setattr(QtWidgets.QMessageBox, "warning", lambda *a, **k: warned.append(a[2]))

    def use(dlg):
        qtbot.mouseClick(dlg.deep_btn, Qt.MouseButton.LeftButton)
        assert dlg.isVisible()  # hata olunca açık kalır
        dlg.reject()

    seen = on_modal(use)
    press(qtbot, w, Qt.Key.Key_D, Qt.KeyboardModifier.ControlModifier)
    assert seen == ["DuplicatesDialog"] and warned == ["bulunamadı"]


def test_settings_dialog_save_validate_cancel(qtbot, make_window, tree, store, monkeypatch):
    w = scanned(qtbot, make_window, tree)
    assert w.dup_chip.isVisible()

    def invalid_then_save(dlg: SettingsDialog):
        dlg.scheduled.setChecked(True)
        dlg.scan_root.setText(str(tree / "yok"))
        dlg.min_dup.setValue(5)
        from PySide6.QtWidgets import QDialogButtonBox

        box = dlg.findChild(QDialogButtonBox)
        qtbot.mouseClick(box.button(QDialogButtonBox.StandardButton.Save), Qt.MouseButton.LeftButton)
        assert dlg.isVisible() and dlg.error_label.isVisible()
        monkeypatch.setattr(
            "ui.dialogs.settings_dialog.QFileDialog.getExistingDirectory", lambda *a, **k: str(tree)
        )
        qtbot.mouseClick(dlg.browse_btn, Qt.MouseButton.LeftButton)
        assert dlg.scan_root.text() == str(tree)
        dlg.days.setValue(3)
        qtbot.mouseClick(box.button(QDialogButtonBox.StandardButton.Save), Qt.MouseButton.LeftButton)

    seen = on_modal(invalid_then_save)
    press(qtbot, w, Qt.Key.Key_Comma, Qt.KeyboardModifier.ControlModifier)
    assert seen == ["SettingsDialog"]
    s = store.settings
    assert (s.scheduled_scan_enabled, s.scheduled_scan_days, s.min_duplicate_size_mb) == (True, 3, 5)
    assert s.scheduled_scan_root == str(tree)
    assert not w.dup_chip.isVisible()  # 3 MB'lık adaylar 5 MB sınırın altında kaldı
    from core import settings as settings_mod

    assert json.loads(settings_mod.SETTINGS_PATH.read_text(encoding="utf-8"))["min_duplicate_size_mb"] == 5

    seen = on_modal(lambda dlg: (dlg.min_dup.setValue(99), dlg.reject()))
    w._open_settings()
    assert seen == ["SettingsDialog"] and store.settings.min_duplicate_size_mb == 5


def test_help_and_about(qtbot, make_window):
    w = make_window()
    text = {}

    def read_help(dlg: QDialog):
        text["help"] = " ".join(lbl.text() for lbl in dlg.findChildren(type(w.scan_status)))
        dlg.accept()

    seen = on_modal(read_help)
    press(qtbot, w, Qt.Key.Key_F1)
    assert seen == ["HelpDialog"]
    for key in ("F5", "Ctrl+D", "Ctrl+1", "Shift+F10", "Alt+Home", "Delete"):
        assert key in text["help"], key
    about = next(a for m in w.menuBar().actions() if m.text() == "Yardım" for a in m.menu().actions() if a.text() == "Hakkında")
    seen = on_modal(lambda dlg: dlg.accept())
    about.trigger()
    assert seen == ["AboutDialog"]


def test_menu_bar_lists_every_action(qtbot, make_window):
    w = make_window()
    menus = {m.text(): [a.text() for a in m.menu().actions() if a.text()] for m in w.menuBar().actions()}
    assert list(menus) == ["Dosya", "Görünüm", "Araçlar", "Yardım"]
    assert "Önbelleği atlayarak tara" in menus["Dosya"] and "Çık" in menus["Dosya"]
    assert menus["Araçlar"] == ["Tekrar adayları", "Ayarlar"]


def test_ctrl_q_closes(qtbot, make_window):
    w = make_window()
    press(qtbot, w, Qt.Key.Key_Q, Qt.KeyboardModifier.ControlModifier)
    qtbot.waitUntil(lambda: not w.isVisible(), timeout=3000)


@pytest.mark.parametrize("button,picks", [("start_btn", False), ("folder_btn", True)])
def test_welcome_dialog_buttons(qtbot, button, picks):
    dlg = WelcomeDialog()
    qtbot.addWidget(dlg)
    dlg.show()
    qtbot.waitExposed(dlg)
    qtbot.mouseClick(getattr(dlg, button), Qt.MouseButton.LeftButton)
    assert dlg.result() == QDialog.DialogCode.Accepted and dlg.pick_folder is picks


def test_about_and_help_standalone(qtbot):
    for cls in (AboutDialog, HelpDialog):
        dlg = cls()
        qtbot.addWidget(dlg)
        dlg.show()
        qtbot.waitExposed(dlg)
        qtbot.keyClick(dlg, Qt.Key.Key_Escape)
        assert not dlg.isVisible()


def test_scheduled_scan_runs_when_due(qtbot, make_window, tree, store):
    store.settings.scheduled_scan_enabled = True
    store.settings.scheduled_scan_root = str(tree)
    store.settings.last_scheduled_scan_utc = "2000-01-01T00:00:00+00:00"
    w = make_window()
    w._check_scheduled_scan()
    wait_scan(qtbot, w)
    assert w._root.name == "Ornek" and store.settings.last_scheduled_scan_utc.startswith("20")
    w._root = None
    w._check_scheduled_scan()  # henüz vakti gelmedi
    assert not w._scanning
