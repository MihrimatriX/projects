"""Arama paleti: yazma, gezinme, açma, filtreler, kısayollar, sağ tık menüsü, hata/boş durumları."""

import pytest
from PySide6.QtCore import QPoint, Qt, QTimer
from PySide6.QtWidgets import QApplication, QDialog, QPushButton, QToolButton

from ui import spotlight_window
from ui.spotlight_window import SpotlightWindow
from utils import search_history


@pytest.fixture
def win(qtbot, demo_root, monkeypatch):
    opened = []
    monkeypatch.setattr(spotlight_window, "open_file", lambda p: opened.append(("file", p)))
    monkeypatch.setattr(spotlight_window, "open_containing_folder", lambda p: opened.append(("folder", p)))
    w = SpotlightWindow()
    qtbot.addWidget(w)
    w.opened = opened
    w.present()
    qtbot.waitExposed(w)
    w.activateWindow()
    yield w
    w.shutdown()


def _search(qtbot, w, text):
    w.panel.search_input.clear()
    qtbot.keyClicks(w.panel.search_input, text)
    qtbot.waitUntil(lambda: bool(w.panel._result_rows) or w.panel._empty_title.text() == "Sonuç bulunamadı", timeout=5000)
    qtbot.waitUntil(lambda: not (w._search_worker and w._search_worker.isRunning()), timeout=5000)


def _key(qtbot, w, key, mods=Qt.KeyboardModifier.NoModifier):
    qtbot.keyClick(w.panel.search_input, key, mods)


def test_empty_state_and_accessible_names(win):
    p = win.panel
    assert win.isVisible()
    assert p._empty_title.text() == "Aramak için yazmaya başlayın"
    assert p.roots_label.text() == "~/Projeler"
    assert p.search_input.accessibleName()
    for btn in p.findChildren(QToolButton) + p.findChildren(QPushButton):
        assert btn.accessibleName() or btn.text(), btn


def test_type_navigate_open_and_folder(qtbot, win):
    _search(qtbot, win, "rapor")
    rows = win.panel._result_rows
    assert len(rows) >= 3
    assert win.panel.result_count_label.text() == f"{len(rows)} sonuç"
    # Dosya adı satırı kırpılmamalı (eskiden düzen boşlukları yüzünden 7 px kalıyordu)
    name = rows[0].name_label
    qtbot.waitUntil(lambda: name.height() >= name.sizeHint().height(), timeout=2000)
    assert win._selected == 0
    _key(qtbot, win, Qt.Key.Key_Down)
    assert win._selected == 1 and rows[1]._selected and not rows[0]._selected
    _key(qtbot, win, Qt.Key.Key_Up)
    assert win._selected == 0
    expected = str(win._results[0].path)
    _key(qtbot, win, Qt.Key.Key_Return)
    assert win.opened == [("file", expected)]
    assert not win.isVisible()  # açınca palet kapanır

    win.present()
    _search(qtbot, win, "rapor")
    _key(qtbot, win, Qt.Key.Key_Return, Qt.KeyboardModifier.ControlModifier)
    assert win.opened[-1][0] == "folder"


def test_mouse_click_and_double_click_rows(qtbot, win):
    _search(qtbot, win, "rapor")
    rows = win.panel._result_rows
    qtbot.mouseClick(rows[1], Qt.MouseButton.LeftButton)
    assert win._selected == 1
    qtbot.mouseDClick(rows[1], Qt.MouseButton.LeftButton)
    assert win.opened and win.opened[-1] == ("file", str(win._results[1].path))


def test_context_menu_actions(qtbot, win):
    _search(qtbot, win, "rapor")
    menu = win._result_menu(1)
    labels = [a.text().split("\t")[0] for a in menu.actions()]
    assert labels == ["Aç", "Klasörde göster", "Yolu kopyala"]
    menu.actions()[2].trigger()
    assert QApplication.clipboard().text() == str(win._results[1].path)
    assert win.panel.result_count_label.text() == "Yol kopyalandı"
    menu.actions()[1].trigger()
    assert win.opened[-1] == ("folder", str(win._results[1].path))
    # Gerçek sağ tık sinyali menüyü açar (exec engellemesin diye menü hemen kapatılır)
    win.present()
    _search(qtbot, win, "rapor")
    QTimer.singleShot(50, lambda: QApplication.activePopupWidget() and QApplication.activePopupWidget().close())
    win.panel._result_rows[0].menu_requested.emit(0, QPoint(10, 10))


def test_copy_path_shortcut(qtbot, win):
    _search(qtbot, win, "yillik")
    qtbot.keyClick(win.panel.search_input, Qt.Key.Key_C, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier)
    qtbot.waitUntil(lambda: QApplication.clipboard().text().endswith("yillik_rapor_2025.pdf"), timeout=2000)


def test_filter_chips_mouse_and_ctrl_digits(qtbot, win):
    _search(qtbot, win, "rapor")
    chips = win.panel._filter_buttons
    qtbot.mouseClick(chips["code"], Qt.MouseButton.LeftButton)
    assert win.panel.active_filter == "code" and chips["code"].isChecked() and not chips["all"].isChecked()
    qtbot.waitUntil(lambda: not win._search_worker.isRunning(), timeout=5000)
    qtbot.waitUntil(lambda: all(r.path.suffix in {".py", ".md"} for r in win._results) and bool(win._results), timeout=5000)

    qtbot.keyClick(win.panel.search_input, Qt.Key.Key_4, Qt.KeyboardModifier.ControlModifier)
    qtbot.waitUntil(lambda: win.panel.active_filter == "images", timeout=2000)
    qtbot.keyClick(win.panel.search_input, Qt.Key.Key_1, Qt.KeyboardModifier.ControlModifier)
    qtbot.waitUntil(lambda: win.panel.active_filter == "all", timeout=2000)
    assert all(b.toolTip().startswith(b.text()) for b in chips.values())


def test_no_results_and_escape(qtbot, win):
    _search(qtbot, win, "zzqqxxyy")
    assert win.panel._empty_title.text() == "Sonuç bulunamadı"
    _key(qtbot, win, Qt.Key.Key_Escape)  # metin varken: temizle
    assert win.panel.search_input.text() == "" and win.isVisible()
    _key(qtbot, win, Qt.Key.Key_Escape)  # boşken: kapat
    assert not win.isVisible()


def test_up_arrow_recalls_last_search(qtbot, win):
    search_history.record_search("butce", 1, 1)
    win._run_search()
    assert "butce" in win.panel._empty_detail.text()
    _key(qtbot, win, Qt.Key.Key_Up)
    assert win.panel.search_input.text() == "butce"


def test_html_in_file_name_is_escaped(qtbot, win):
    _search(qtbot, win, "a&b")
    names = [r.name_label.text() for r in win.panel._result_rows]
    assert any("a&amp;b" in n for n in names)


def test_search_error_shows_retry_badge(qtbot, win):
    badge = win.panel.index_badge
    win._on_search_failed("disk okunamadı")
    assert win.panel._empty_title.text() == "Arama tamamlanamadı"
    assert badge._retry.isVisibleTo(win) and badge._text.text() == "Arama hatası"
    qtbot.mouseClick(badge._retry, Qt.MouseButton.LeftButton)
    assert not badge._retry.isVisibleTo(win)


def test_settings_button_and_ctrl_comma_open_dialog(qtbot, win):
    seen = []

    def close_dialog():
        dlg = QApplication.activeModalWidget()
        seen.append(type(dlg).__name__)
        if isinstance(dlg, QDialog):
            dlg.reject()

    settings_btn = win.panel.findChild(QToolButton)
    QTimer.singleShot(200, close_dialog)
    qtbot.mouseClick(settings_btn, Qt.MouseButton.LeftButton)
    QTimer.singleShot(200, close_dialog)
    _key(qtbot, win, Qt.Key.Key_Comma, Qt.KeyboardModifier.ControlModifier)
    assert seen == ["SettingsDialog", "SettingsDialog"]


def test_click_outside_panel_dismisses(qtbot, win):
    qtbot.mouseClick(win, Qt.MouseButton.LeftButton, pos=QPoint(3, win.height() - 3))
    assert not win.isVisible()


def test_toggle_shows_and_hides(qtbot, win):
    win.toggle()
    assert not win.isVisible()
    win.toggle()
    assert win.isVisible() and win.panel.search_input.text() == ""
