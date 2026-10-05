"""Ana pencere, araç çubuğu, ☰ menüsü, kısayollar, kural paneli, önizleme tablosu ve tüm diyaloglar."""
from __future__ import annotations

import json
from pathlib import Path

import pytest
from PySide6.QtCore import QMimeData, QPointF, Qt, QTimer, QUrl
from PySide6.QtGui import QDragEnterEvent, QDropEvent
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QDialog,
    QLineEdit,
    QMenu,
    QMessageBox,
    QTableWidgetSelectionRange,
)

from core.models import RuleType
from ui import main_window as mw
from ui.dialogs.welcome_dialog import STEPS, WelcomeDialog

_watchers: list[dict] = []


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


@pytest.fixture(autouse=True)
def _stop_watchers():
    yield
    for state in _watchers:
        state["alive"] = False
    _watchers.clear()


class Msgs(list):
    answer: dict


@pytest.fixture
def msgs(monkeypatch):
    seen = Msgs()
    seen.answer = {"value": QMessageBox.StandardButton.Yes}
    for kind in ("information", "warning", "critical"):
        monkeypatch.setattr(
            mw.QMessageBox, kind,
            lambda *a, k=kind, **kw: seen.append((k, a[2] if len(a) > 2 else "")) or QMessageBox.StandardButton.Ok,
        )
    monkeypatch.setattr(mw.QMessageBox, "question", lambda *a, **kw: seen.append(("question", a[2])) or seen.answer["value"])
    return seen


def press(qtbot, w, key, mods=Qt.KeyboardModifier.NoModifier, target=None):
    w.activateWindow()
    qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
    qtbot.keyClick(target or w, key, mods)


CTRL = Qt.KeyboardModifier.ControlModifier
SHIFT = Qt.KeyboardModifier.ShiftModifier


def table(w):
    return w.preview_stack.preview_table


def names(w, col=0):
    t = table(w)
    return [t.item(i, col).text() for i in range(t.rowCount())]


def wait_rows(qtbot, w, n):
    qtbot.waitUntil(lambda: table(w).rowCount() == n and not w._debounce.isActive(), timeout=5000)


def load(qtbot, w, folder: Path, n: int = 4):
    w._load_folder(folder)
    wait_rows(qtbot, w, n)


def card_edit(w, label: str, card: int = 0) -> QLineEdit:
    return next(e for e in w.rules_panel._cards[card].findChildren(QLineEdit) if e.accessibleName() == label)


def set_find_replace(qtbot, w, find: str, repl: str):
    e = card_edit(w, "Ara")
    e.clear()
    qtbot.keyClicks(e, find)
    r = card_edit(w, "Değiştir")
    r.clear()
    qtbot.keyClicks(r, repl)
    qtbot.waitUntil(lambda: not w._debounce.isActive(), timeout=3000)
    QApplication.processEvents()


# --- Boş durum, dosya ekleme ----------------------------------------------------------------

def test_empty_state(qtbot, make_window, msgs):
    w = make_window()
    qtbot.waitUntil(lambda: w.preview_stack.empty_pane.isVisible(), timeout=3000)
    assert not w.apply_btn.isEnabled() and w.apply_btn.text() == "Dosya Yok"
    assert w.path_label.text() == "Dosya seçilmedi"
    assert w.preview_stack.add_btn.isVisible() and w.preview_stack.folder_btn.isVisible()
    press(qtbot, w, Qt.Key.Key_E, CTRL)
    press(qtbot, w, Qt.Key.Key_Return, CTRL)
    assert [k for k, _ in msgs] == ["information", "warning"]
    press(qtbot, w, Qt.Key.Key_Z, CTRL)
    assert w.path_label.text() == "Geri alınacak işlem yok"
    press(qtbot, w, Qt.Key.Key_Y, CTRL)
    assert w.path_label.text() == "Yinelenecek işlem yok"


def test_pick_folder_shortcut_and_empty_button(qtbot, make_window, folder, monkeypatch, store):
    w = make_window()
    monkeypatch.setattr(mw.QFileDialog, "getExistingDirectory", lambda *a, **k: "")
    press(qtbot, w, Qt.Key.Key_O, CTRL | SHIFT)
    assert w._files == []
    monkeypatch.setattr(mw.QFileDialog, "getExistingDirectory", lambda *a, **k: str(folder))
    qtbot.waitUntil(lambda: w.preview_stack.folder_btn.isVisible(), timeout=3000)
    qtbot.mouseClick(w.preview_stack.folder_btn, Qt.MouseButton.LeftButton)
    wait_rows(qtbot, w, 4)
    assert w.path_label.toolTip() == f"4 dosya · {folder}"
    assert store.settings.last_folder == str(folder)
    w._clear_files()
    press(qtbot, w, Qt.Key.Key_O, CTRL | SHIFT)
    wait_rows(qtbot, w, 4)


def test_add_files_ctrl_o_toolbar_and_cancel(qtbot, make_window, folder, monkeypatch):
    w = make_window()
    picked = [str(folder / "Tatil Foto 1.jpg"), str(folder / "notlar.txt")]
    monkeypatch.setattr(mw.QFileDialog, "getOpenFileNames", lambda *a, **k: ([], ""))
    press(qtbot, w, Qt.Key.Key_O, CTRL)
    assert w._files == []
    monkeypatch.setattr(mw.QFileDialog, "getOpenFileNames", lambda *a, **k: (picked, ""))
    qtbot.mouseClick(w.toolbar._add_btn, Qt.MouseButton.LeftButton)
    wait_rows(qtbot, w, 2)
    assert w._folder is None and w.path_label.toolTip() == f"2 dosya · {folder}"
    press(qtbot, w, Qt.Key.Key_O, CTRL)  # aynı dosyalar tekrar eklenmez
    assert len(w._files) == 2


def test_drag_and_drop(qtbot, make_window, folder):
    w = make_window()
    zone = w.centralWidget()
    mime = QMimeData()
    mime.setUrls([QUrl.fromLocalFile(str(folder / "notlar.txt")), QUrl.fromLocalFile(str(folder / "Tatil Foto 2.jpg"))])
    pos = QPointF(zone.rect().center())
    enter = QDragEnterEvent(pos.toPoint(), Qt.DropAction.CopyAction, mime, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier)
    QApplication.sendEvent(zone, enter)
    assert w.preview_stack.drop_overlay.isVisible()
    drop = QDropEvent(pos, Qt.DropAction.CopyAction, mime, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier)
    QApplication.sendEvent(zone, drop)
    assert not w.preview_stack.drop_overlay.isVisible()
    wait_rows(qtbot, w, 2)
    # Klasör bırakmak klasörü yükler
    mime2 = QMimeData()
    mime2.setUrls([QUrl.fromLocalFile(str(folder))])
    no_mod = Qt.KeyboardModifier.NoModifier
    QApplication.sendEvent(zone, QDragEnterEvent(pos.toPoint(), Qt.DropAction.CopyAction, mime2, Qt.MouseButton.LeftButton, no_mod))
    QApplication.sendEvent(zone, QDropEvent(pos, Qt.DropAction.CopyAction, mime2, Qt.MouseButton.LeftButton, no_mod))
    wait_rows(qtbot, w, 4)


# --- Uygula, geri al, yinele ----------------------------------------------------------------

def test_apply_undo_redo_cycle(qtbot, make_window, folder, msgs):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "Tatil Foto", "Yaz")
    assert "Yaz 1.jpg" in names(w, 2)
    assert w.apply_btn.isEnabled() and w.apply_btn.text() == "3 Dosyayı Uygula"
    assert w.stat_valid.text() == "✓ 3 geçerli"  # notlar.txt değişmiyor
    qtbot.mouseClick(w.apply_btn, Qt.MouseButton.LeftButton)
    assert msgs[0][0] == "question" and "3 dosya" in msgs[0][1]
    assert sorted(p.name for p in folder.iterdir()) == ["Yaz 1.jpg", "Yaz 2.jpg", "Yaz 3.jpg", "notlar.txt"]
    assert w.toolbar.undo_button.isEnabled() and not w.toolbar.redo_button.isEnabled()

    press(qtbot, w, Qt.Key.Key_Z, CTRL)
    assert (folder / "Tatil Foto 1.jpg").exists() and w.toolbar.redo_button.isEnabled()
    assert "geri alındı" in w.path_label.text()
    qtbot.mouseClick(w.toolbar.redo_button, Qt.MouseButton.LeftButton)
    assert (folder / "Yaz 1.jpg").exists()
    qtbot.mouseClick(w.toolbar.undo_button, Qt.MouseButton.LeftButton)
    press(qtbot, w, Qt.Key.Key_Z, CTRL | SHIFT)  # Ctrl+Shift+Z de yineler
    assert (folder / "Yaz 3.jpg").exists() and not w.toolbar.redo_button.isEnabled()


def test_cancel_confirm_renames_nothing(qtbot, make_window, folder, msgs):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "Foto", "F")
    msgs.answer["value"] = QMessageBox.StandardButton.No
    press(qtbot, w, Qt.Key.Key_Return, CTRL)
    assert msgs[-1][0] == "question" and (folder / "Tatil Foto 1.jpg").exists()


def test_quick_apply_skips_confirm(qtbot, make_window, folder, msgs):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "notlar", "notes")
    press(qtbot, w, Qt.Key.Key_Return, CTRL | SHIFT)
    assert msgs == [] and (folder / "notes.txt").exists()


def test_undo_keeps_hand_picked_list(qtbot, make_window, folder, msgs):
    """Tek tek eklenen dosyalarda geri al tüm klasörü listeye doldurmamalı."""
    w = make_window()
    w._ingest_paths([folder / "Tatil Foto 1.jpg", folder / "Tatil Foto 2.jpg"])
    wait_rows(qtbot, w, 2)
    set_find_replace(qtbot, w, "Tatil ", "")
    press(qtbot, w, Qt.Key.Key_Return, CTRL | SHIFT)
    qtbot.waitUntil(lambda: sorted(names(w, 0)) == ["Foto 1.jpg", "Foto 2.jpg"], timeout=3000)
    press(qtbot, w, Qt.Key.Key_Z, CTRL)
    wait_rows(qtbot, w, 2)
    assert sorted(names(w, 0)) == ["Tatil Foto 1.jpg", "Tatil Foto 2.jpg"]
    press(qtbot, w, Qt.Key.Key_Y, CTRL)
    wait_rows(qtbot, w, 2)
    assert sorted(names(w, 0)) == ["Foto 1.jpg", "Foto 2.jpg"]


def test_undo_survives_restart(qtbot, make_window, folder, msgs, store):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "notlar", "n")
    press(qtbot, w, Qt.Key.Key_Return, CTRL | SHIFT)
    w.close()
    w2 = make_window()
    assert w2.toolbar.undo_button.isEnabled()
    press(qtbot, w2, Qt.Key.Key_Z, CTRL)
    assert (folder / "notlar.txt").exists()


def test_conflicts_block_apply_and_filter(qtbot, make_window, folder, msgs):
    w = make_window()
    load(qtbot, w, folder)
    w.rules_panel._cards[0].regex_cb.setChecked(True)
    set_find_replace(qtbot, w, r"Foto \d", "Foto")  # üç dosya da "Tatil Foto.jpg" olur
    qtbot.waitUntil(lambda: "çakışma" in w.stat_conflict.text(), timeout=3000)
    assert not w.apply_btn.isEnabled() and w.conflict_filter_btn.isEnabled()
    qtbot.mouseClick(w.conflict_filter_btn, Qt.MouseButton.LeftButton)
    assert table(w).rowCount() == 3
    qtbot.mouseClick(w.conflict_filter_btn, Qt.MouseButton.LeftButton)
    assert table(w).rowCount() == 4
    press(qtbot, w, Qt.Key.Key_Return, CTRL)
    assert msgs[-1] == ("warning", "Çakışma veya hata giderilmeden uygulanamaz.")
    assert (folder / "Tatil Foto 1.jpg").exists()


def test_regex_error_shown_on_card(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    w.rules_panel._cards[0].regex_cb.setChecked(True)
    set_find_replace(qtbot, w, "(", "x")
    card = w.rules_panel._cards[0]
    qtbot.waitUntil(lambda: card.error_label.isVisible(), timeout=3000)
    assert not w.apply_btn.isEnabled()
    set_find_replace(qtbot, w, "Foto", "x")
    qtbot.waitUntil(lambda: not card.error_label.isVisible(), timeout=3000)


# --- Önizleme tablosu: arama, silme, sağ tık -------------------------------------------------

def test_search_filters_rows(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    press(qtbot, w, Qt.Key.Key_F, CTRL)
    assert w.search_edit.hasFocus()
    qtbot.keyClicks(w.search_edit, "foto 2")
    assert names(w) == ["Tatil Foto 2.jpg"]
    w.search_edit.clear()
    assert table(w).rowCount() == 4


def test_delete_removes_selected_rows_even_when_searching(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    t = table(w)
    t.setRangeSelected(QTableWidgetSelectionRange(0, 0, 1, 3), True)  # iki satır (çoklu seçim)
    t.setFocus()
    press(qtbot, w, Qt.Key.Key_Delete, target=t)
    assert w.path_label.text() == "2 dosya listeden çıkarıldı"
    wait_rows(qtbot, w, 2)
    w.search_edit.setText("notlar")
    t.selectRow(0)
    t.setFocus()
    press(qtbot, w, Qt.Key.Key_Delete, target=t)
    assert all(f.name != "notlar.txt" for f in w._files)
    assert (folder / "notlar.txt").exists()  # yalnızca listeden çıkar, diske dokunmaz


def test_delete_in_rule_field_edits_text_not_list(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    e = card_edit(w, "Ara")
    qtbot.keyClicks(e, "ab")
    e.setCursorPosition(0)
    table(w).selectRow(0)
    e.setFocus()
    press(qtbot, w, Qt.Key.Key_Delete, target=e)
    assert e.text() == "b" and len(w._files) == 4


def test_context_menu_uses_row_under_cursor(qtbot, make_window, folder, monkeypatch):
    w = make_window()
    load(qtbot, w, folder)
    revealed = []
    monkeypatch.setattr(mw, "reveal_in_explorer", lambda p: revealed.append(p))
    t = table(w)
    t.selectRow(0)
    pos = t.visualItemRect(t.item(2, 0)).center()

    def pick(text):
        def choose(menu: QMenu):
            action = next(a for a in menu.actions() if a.text() == text)
            menu.close()
            action.trigger()
        return on_modal(choose, popup=True)

    seen = pick("Explorer'da göster")
    t.customContextMenuRequested.emit(pos)
    qtbot.waitUntil(lambda: bool(seen), timeout=3000)
    assert revealed and revealed[0].name == names(w)[2]
    target = names(w)[2]
    seen = pick("Listeden çıkar")
    t.customContextMenuRequested.emit(pos)
    qtbot.waitUntil(lambda: bool(seen), timeout=3000)
    wait_rows(qtbot, w, 3)
    assert target not in names(w)


# --- Kural paneli ---------------------------------------------------------------------------

def test_rule_types_move_toggle_remove(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    panel = w.rules_panel
    qtbot.mouseClick(panel.add_btn, Qt.MouseButton.LeftButton)
    assert len(panel._cards) == 2
    panel._cards[1].type_combo.setCurrentIndex(list(RuleType).index(RuleType.NUMBERING))
    qtbot.waitUntil(lambda: all(n.startswith("00") for n in names(w, 2)), timeout=3000)
    # büyük/küçük harf kuralı
    qtbot.mouseClick(panel.add_btn, Qt.MouseButton.LeftButton)
    panel._cards[2].type_combo.setCurrentIndex(list(RuleType).index(RuleType.CASE))
    combo = next(c for c in panel._cards[2].findChildren(QComboBox) if c.accessibleName() == "Harf modu")
    combo.setCurrentIndex(1)  # BÜYÜK HARF
    qtbot.waitUntil(lambda: any("FOTO" in n for n in names(w, 2)), timeout=3000)
    # sıra: büyük harf kuralını yukarı taşı
    rule = panel._cards[2].rule
    qtbot.mouseClick(panel._cards[2].up_btn, Qt.MouseButton.LeftButton)
    assert panel.rules[1] is rule and panel._cards[1].title.text().startswith("2 ·")
    qtbot.mouseClick(panel._cards[1].down_btn, Qt.MouseButton.LeftButton)
    assert panel.rules[2] is rule
    # devre dışı bırak → numara kalkar
    panel._cards[1].enable_cb.setChecked(False)
    qtbot.waitUntil(lambda: not any(n.startswith("00") for n in names(w, 2)), timeout=3000)
    qtbot.mouseClick(panel._cards[2].remove_btn, Qt.MouseButton.LeftButton)
    assert len(panel._cards) == 2


def test_remove_targets_the_clicked_card_among_identical_rules(qtbot, make_window):
    w = make_window()
    panel = w.rules_panel
    qtbot.mouseClick(panel.add_btn, Qt.MouseButton.LeftButton)
    qtbot.mouseClick(panel.add_btn, Qt.MouseButton.LeftButton)
    second, third = panel.rules[1], panel.rules[2]
    assert second == third and second is not third  # aynı alanlar
    qtbot.mouseClick(panel._cards[2].remove_btn, Qt.MouseButton.LeftButton)
    assert panel.rules[1] is second and len(panel.rules) == 2
    qtbot.mouseClick(panel._cards[1].up_btn, Qt.MouseButton.LeftButton)
    assert panel.rules[0] is second
    # son kural silinemez
    qtbot.mouseClick(panel._cards[0].remove_btn, Qt.MouseButton.LeftButton)
    qtbot.mouseClick(panel._cards[0].remove_btn, Qt.MouseButton.LeftButton)
    assert len(panel.rules) == 1


def test_condition_ext_and_extension_rule(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    card = w.rules_panel._cards[0]
    card.type_combo.setCurrentIndex(list(RuleType).index(RuleType.EXTENSION))
    old = card_edit(w, "Eski uzantı")
    new = card_edit(w, "Yeni uzantı")
    qtbot.keyClicks(old, "jpg")
    qtbot.keyClicks(new, "jpeg")
    qtbot.waitUntil(lambda: "Tatil Foto 1.jpeg" in names(w, 2), timeout=3000)
    qtbot.keyClicks(card.condition_edit, "txt")
    qtbot.waitUntil(lambda: "Tatil Foto 1.jpg" in names(w, 2), timeout=3000)
    assert "(ext:txt)" in card.title.text()


def test_exif_rule_labels_are_turkish(qtbot, make_window):
    w = make_window()
    card = w.rules_panel._cards[0]
    card.type_combo.setCurrentIndex(list(RuleType).index(RuleType.EXIF_DATE))
    combo = next(c for c in card.findChildren(QComboBox) if c.accessibleName() == "EXIF ad modu")
    texts = [combo.itemText(i) for i in range(combo.count())]
    assert texts[0] == "EXIF, yoksa değiştirme tarihi" and not any("_" in t for t in texts)
    assert all(e.accessibleName() for e in card.findChildren(QLineEdit))
    combo.setCurrentIndex(2)
    assert card.rule.exif_naming_mode.name == "MTIME_ONLY"
    QApplication.processEvents()
    card = w.rules_panel._cards[0]
    # Kart panele sığmalı; ↓ / ✕ düğmeleri kırpılmamalı (uzun combo metni kartı genişletiyordu)
    assert card.remove_btn.geometry().right() < card.width() <= card.parentWidget().width()
    # 3 kart + dikey kaydırma çubuğu: hiçbir kart tipi görünür alandan geniş olmamalı
    from core.models import Rule

    w.rules_panel.set_rules([Rule(rule_type=t) for t in RuleType])
    QApplication.processEvents()
    viewport = w.rules_panel._cards[0].parentWidget().parentWidget().width()
    assert all(c.minimumSizeHint().width() <= viewport for c in w.rules_panel._cards)


def test_presets(qtbot, make_window, folder):
    w = make_window()
    load(qtbot, w, folder)
    from PySide6.QtWidgets import QPushButton

    chips = [b for b in w.rules_panel.findChildren(QPushButton) if b.objectName() == "ChipButton"]
    from core.presets import PRESETS

    assert len(chips) == len(PRESETS) and all(b.toolTip() for b in chips)
    for chip in chips:
        qtbot.mouseClick(chip, Qt.MouseButton.LeftButton)
        qtbot.waitUntil(lambda: not w._debounce.isActive(), timeout=3000)
        assert w.rules_panel._cards
    seq = next(b for b in chips if b.text() == "Sıra Numarası")
    qtbot.mouseClick(seq, Qt.MouseButton.LeftButton)
    qtbot.waitUntil(lambda: all(n.startswith("00") for n in names(w, 2)), timeout=3000)


# --- Makro, dışa/içe aktarma ----------------------------------------------------------------

def test_macro_save_and_run(qtbot, make_window, folder, msgs):
    w = make_window()
    press(qtbot, w, Qt.Key.Key_R, CTRL | SHIFT)
    assert msgs[-1][0] == "information" and "Kayıtlı makro yok" in msgs[-1][1]
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "Tatil", "Bayram")
    press(qtbot, w, Qt.Key.Key_S, CTRL | SHIFT)
    assert "Makro kaydedildi" in w.path_label.text()
    set_find_replace(qtbot, w, "x", "y")
    press(qtbot, w, Qt.Key.Key_R, CTRL | SHIFT)
    assert w.rules_panel.rules[0].pattern == "Tatil"
    qtbot.waitUntil(lambda: "Bayram Foto 1.jpg" in names(w, 2), timeout=3000)


@pytest.mark.parametrize("via", ["shortcut", "button"])
def test_export_preview_csv_json(qtbot, make_window, folder, tmp_path, monkeypatch, via):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "Tatil", "T")
    out = {"csv": tmp_path / "o.csv", "json": tmp_path / "o.json"}
    for kind in ("csv", "json"):
        monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, k=kind, **kw: (str(out[k]), ""))
        if via == "shortcut":
            press(qtbot, w, Qt.Key.Key_E, CTRL | (SHIFT if kind == "json" else Qt.KeyboardModifier.NoModifier))
        else:
            from PySide6.QtWidgets import QPushButton

            btn = next(b for b in w.findChildren(QPushButton) if b.text() == kind.upper())
            qtbot.mouseClick(btn, Qt.MouseButton.LeftButton)
    assert "T Foto 1.jpg" in out["csv"].read_text(encoding="utf-8-sig")
    assert any(r.get("new_name") == "T Foto 1.jpg" for r in json.loads(out["json"].read_text(encoding="utf-8")))


def test_rules_json_roundtrip_and_bad_file(qtbot, make_window, tmp_path, monkeypatch, msgs):
    w = make_window()
    set_find_replace(qtbot, w, "a", "b")
    dest = tmp_path / "kurallar.json"
    monkeypatch.setattr(mw.QFileDialog, "getSaveFileName", lambda *a, **k: (str(dest), ""))
    w._export_rules()
    assert dest.is_file()
    set_find_replace(qtbot, w, "zzz", "q")
    monkeypatch.setattr(mw.QFileDialog, "getOpenFileName", lambda *a, **k: (str(dest), ""))
    w._import_rules()
    assert w.rules_panel.rules[0].pattern == "a"
    bad = tmp_path / "bozuk.json"
    bad.write_text("{bozuk", encoding="utf-8")
    monkeypatch.setattr(mw.QFileDialog, "getOpenFileName", lambda *a, **k: (str(bad), ""))
    w._import_rules()
    assert msgs[-1][0] == "critical"


# --- Menü, tema, ayarlar, diyaloglar ---------------------------------------------------------

def test_hamburger_menu_lists_actions_with_shortcuts(qtbot, make_window):
    w = make_window()
    menu = w.toolbar.menu_button.menu()
    subs = {a.text(): a.menu() for a in menu.actions()}
    assert list(subs) == ["Dosya", "Düzen", "Görünüm", "Yardım"]
    edit = {a.text(): a.shortcut().toString() for a in subs["Düzen"].actions() if a.text()}
    assert edit["Geri Al"] == "Ctrl+Z" and edit["Yinele"] == "Ctrl+Y" and edit["Listeden Çıkar"] == "Del"
    assert w.toolbar.menu_button.accessibleName() and w.toolbar.theme_button.accessibleName()


def test_theme_toggle(qtbot, make_window, store):
    w = make_window()
    assert store.settings.theme == "dark"
    press(qtbot, w, Qt.Key.Key_T, CTRL)
    assert store.settings.theme == "light" and w.toolbar.theme_button.text() == "☀"
    qtbot.mouseClick(w.toolbar.theme_button, Qt.MouseButton.LeftButton)
    assert store.settings.theme == "dark"


def test_settings_dialog(qtbot, make_window, folder, store):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "notlar", "n")

    def change(dlg):
        dlg.theme_combo.setCurrentIndex(1)
        dlg.filter_cb.setChecked(True)
        dlg.undo_spin.setValue(7)
        dlg.accept()

    seen = on_modal(change)
    press(qtbot, w, Qt.Key.Key_Comma, CTRL)
    assert seen == ["SettingsDialog"]
    assert store.settings.theme == "light" and store.settings.undo_stack_max == 7
    wait_rows(qtbot, w, 1)  # yalnızca değişenler
    assert names(w, 2) == ["n.txt"]

    seen = on_modal(lambda dlg: (dlg.theme_combo.setCurrentIndex(0), dlg.reject()))
    w._open_settings()
    assert seen == ["SettingsDialog"] and store.settings.theme == "light"


def test_help_about_and_welcome_from_menu(qtbot, make_window):
    w = make_window()
    text = {}

    def read(dlg):
        from PySide6.QtWidgets import QLabel

        text["help"] = " ".join(l.text() for l in dlg.findChildren(QLabel))
        dlg.reject()

    seen = on_modal(read)
    press(qtbot, w, Qt.Key.Key_F1)
    assert seen == ["HelpDialog"]
    for key in ("Ctrl+Y", "Ctrl+F", "Ctrl+Shift+O", "Ctrl+T"):
        assert key in text["help"], key
    assert "sürükleyin veya ↑↓" not in text["help"]  # var olmayan sürükle-sırala vaadi kaldırıldı
    help_menu = next(a.menu() for a in w.toolbar.menu_button.menu().actions() if a.text() == "Yardım")
    for name, cls in (("Hakkında", "AboutDialog"), ("Hoş geldin", "WelcomeDialog")):
        seen = on_modal(lambda dlg: dlg.reject())
        next(a for a in help_menu.actions() if a.text() == name).trigger()
        assert seen == [cls]


def test_welcome_dialog_steps(qtbot):
    dlg = WelcomeDialog()
    qtbot.addWidget(dlg)
    dlg.show()
    qtbot.waitExposed(dlg)
    assert dlg._dot_buttons[0].accessibleName() == "Adım 1"
    qtbot.mouseClick(dlg._dot_buttons[-1], Qt.MouseButton.LeftButton)
    assert dlg.next_btn.text() == "Başla"
    qtbot.mouseClick(dlg._dot_buttons[0], Qt.MouseButton.LeftButton)
    for _ in range(len(STEPS) - 1):
        qtbot.mouseClick(dlg.next_btn, Qt.MouseButton.LeftButton)
    assert dlg.isVisible() and dlg.next_btn.text() == "Başla"
    qtbot.mouseClick(dlg.next_btn, Qt.MouseButton.LeftButton)
    assert dlg.result() == QDialog.DialogCode.Accepted
    dlg2 = WelcomeDialog()
    qtbot.addWidget(dlg2)
    dlg2.show()
    qtbot.mouseClick(dlg2.skip_btn, Qt.MouseButton.LeftButton)
    assert dlg2.result() == QDialog.DialogCode.Accepted and dlg2.skip_next_time()


def test_welcome_shown_once_on_first_start(qtbot, store):
    from ui.main_window import MainWindow

    store.settings.show_welcome = True
    seen = on_modal(lambda dlg: dlg.accept())
    w = MainWindow()
    qtbot.addWidget(w)
    w.show()
    qtbot.waitUntil(lambda: bool(seen), timeout=3000)
    assert seen == ["WelcomeDialog"] and store.settings.show_welcome is False


def test_async_preview_progress_and_cancel(qtbot, make_window, tmp_path, store):
    big = tmp_path / "Cok"
    big.mkdir()
    for i in range(60):
        (big / f"dosya {i:03d}.txt").write_text("x", encoding="utf-8")
    store.settings.preview_async_threshold = 20
    w = make_window()
    load(qtbot, w, big, 60)
    assert not w._progress_row.isVisible()
    w._start_async_preview()
    assert w._progress_row.isVisible()
    qtbot.mouseClick(w.cancel_preview_btn, Qt.MouseButton.LeftButton)
    assert not w._progress_row.isVisible() and w.path_label.text() == "Önizleme iptal edildi"


def test_narrow_window_stacks_panels(qtbot, make_window):
    w = make_window()
    w.resize(820, 700)
    qtbot.waitUntil(lambda: w._splitter.orientation() == Qt.Orientation.Vertical, timeout=3000)
    w.resize(1200, 760)
    qtbot.waitUntil(lambda: w._splitter.orientation() == Qt.Orientation.Horizontal, timeout=3000)


def test_ctrl_q_saves_rules_and_settings_keys(qtbot, make_window, folder, store):
    w = make_window()
    load(qtbot, w, folder)
    set_find_replace(qtbot, w, "kaydet", "x")
    press(qtbot, w, Qt.Key.Key_Q, CTRL)
    qtbot.waitUntil(lambda: not w.isVisible(), timeout=3000)
    from core.settings import data_dir

    data = json.loads((data_dir() / "settings.json").read_text(encoding="utf-8"))
    assert data["last_folder"] == str(folder) and data["last_rules"][0]["pattern"] == "kaydet"
    # Eski sürümle aynı konum ve anahtarlar (geri uyumluluk)
    assert data_dir().parts[-3:] == (".local", "share", "DosyaYenidenAdlandirici")
