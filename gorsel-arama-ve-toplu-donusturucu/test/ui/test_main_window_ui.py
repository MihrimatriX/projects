"""Ana pencerenin tüm kontrolleri: ekleme yolları, codec paneli, ön ayarlar, arama, seçim, dönüştürme,
iptal, hata tekrarı, kuyruk temizleme, çıktı klasörü, üzerine yazma onayı, erişilebilir adlar."""
from __future__ import annotations

import threading
from pathlib import Path

from PySide6.QtCore import QMimeData, QPointF, Qt, QUrl
from PySide6.QtGui import QDropEvent
from PySide6.QtWidgets import QAbstractButton, QComboBox, QLabel, QLineEdit, QMessageBox, QSlider

from ui.main_window import JobRow


def rows(w) -> list[JobRow]:
    return [w._queue_lay.itemAt(i).widget() for i in range(w._queue_lay.count())
            if isinstance(w._queue_lay.itemAt(i).widget(), JobRow)]


def add(w, *paths) -> None:
    w._add_paths([str(p) for p in paths])


def test_empty_state_and_status_hints(window):
    w = window
    assert w._drop.isVisible() and not w._scroll.isVisible()
    assert w._file_count.text() == "0 dosya"
    assert not w._convert_btn.isEnabled() and w._convert_btn.text() == "Dosya ekleyin"
    # Kısayol ipuçları kalıcı "Hazır" mesajının altında gizli kalıyordu
    hints = [lbl for lbl in w.statusBar().findChildren(QLabel) if lbl.objectName() == "KbdHint"]
    assert hints and all(h.isVisible() for h in hints)


def test_add_files_via_ctrl_o_button_and_dropzone(window, images, dialogs, qtbot):
    w = window
    dialogs["files"] = [str(images / "kirmizi.png")]
    qtbot.keyClick(w, Qt.Key.Key_O, Qt.KeyboardModifier.ControlModifier)
    assert len(w._jobs) == 1 and w._status_msg.text() == "1 dosya eklendi"
    assert w._convert_btn.isEnabled() and w._convert_btn.text() == "1 Dosyayı Dönüştür"
    assert w._drop.isHidden() and len(rows(w)) == 1
    assert "64×48" in w._jobs[0].meta or "64" in w._jobs[0].meta

    dialogs["files"] = [str(images / "kirmizi.png")]
    qtbot.mouseClick(w._add_btn, Qt.MouseButton.LeftButton)
    assert len(w._jobs) == 1 and w._status_msg.text() == "Seçilen görseller zaten kuyrukta"

    dialogs["files"] = [str(images / "notlar.txt")]
    qtbot.mouseClick(w._add_btn, Qt.MouseButton.LeftButton)
    assert w._status_msg.text() == "Desteklenen görsel bulunamadı"


def test_dropzone_click_and_keyboard(window, images, dialogs, qtbot):
    w = window
    dialogs["files"] = [str(images / "mavi.png")]
    w._drop.setFocus()
    qtbot.keyClick(w._drop, Qt.Key.Key_Return)  # önceden klavyeyle etkinleşmiyordu
    assert len(w._jobs) == 1
    w._jobs.clear()
    w._sync_ui()
    qtbot.mouseClick(w._drop, Qt.MouseButton.LeftButton)
    assert len(w._jobs) == 1


def test_add_folder_button_and_shortcut(window, images, dialogs, qtbot):
    w = window
    dialogs["folder"] = str(images)
    qtbot.mouseClick(w._add_folder_btn, Qt.MouseButton.LeftButton)
    names = sorted(Path(j.path).name for j in w._jobs)
    assert names == ["bozuk.jpg", "kirmizi.png", "mavi.png", "plaj.jpg", "yesil.jpg"]  # alt klasör dahil
    assert next(j for j in w._jobs if j.path.endswith("bozuk.jpg")).meta == "okunamadı"
    w._jobs.clear()
    w._sync_ui()
    qtbot.keyClick(w, Qt.Key.Key_O, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier)
    assert len(w._jobs) == 5


def test_drag_and_drop_on_window(window, images):
    w = window
    mime = QMimeData()
    mime.setUrls([QUrl.fromLocalFile(str(images / "Tatil"))])
    ev = QDropEvent(QPointF(200, 200), Qt.DropAction.CopyAction, mime, Qt.MouseButton.NoButton,
                    Qt.KeyboardModifier.NoModifier)
    w.dropEvent(ev)
    assert [Path(j.path).name for j in w._jobs] == ["plaj.jpg"]


def test_format_combo_switches_codec_panel(window, qtbot):
    w = window
    expect = {
        "webp": [w._webp_lossless, w._webp_method[0]],
        "jpeg": [w._jpeg_progressive, w._jpeg_optimize, w._jpeg_sub],
        "png": [w._png_compress[0], w._png_optimize],
        "avif": [],
    }
    for fmt, shown in expect.items():
        w._fmt.setCurrentText(fmt)
        visible = {id(x) for x in shown}
        for v in expect.values():
            for x in v:
                assert x.isVisible() == (id(x) in visible), (fmt, x)
        assert w._codec_title.text().upper().startswith(fmt.upper()[:3])
        assert w._quality.isEnabled() == (fmt != "png")
    w._fmt.setCurrentText("webp")
    w._webp_lossless.setChecked(True)
    assert not w._quality.isEnabled() and w._quality_label.text() == "—"
    w._webp_lossless.setChecked(False)
    w._quality.setValue(60)
    assert w._quality_label.text() == "%60" and w._current_options().quality == 60
    w._webp_method[1].setValue(6)
    assert w._webp_method[2].text() == "6" and w._current_options().webp_method == 6


def test_size_presets_are_exclusive_and_update_meta(window, images, qtbot):
    w = window
    add(w, images / "yesil.jpg")
    btn_800 = next(b for b in w._width_btn_list if b.property("presetValue") == 800)
    qtbot.mouseClick(btn_800, Qt.MouseButton.LeftButton)
    assert [b.isChecked() for b in w._width_btn_list] == [False, True, False, False]
    assert w._current_options().max_width == 800
    assert "800" in w._jobs[0].meta  # 3000x2000 -> 800x533
    btn_1080 = next(b for b in w._height_btn_list if b.property("presetValue") == 1080)
    qtbot.mouseClick(btn_1080, Qt.MouseButton.LeftButton)
    assert w._current_options().max_height == 1080 and btn_1080.isChecked()
    qtbot.mouseClick(btn_1080, Qt.MouseButton.LeftButton)  # tekrar tıklama seçimi kaldırmamalı
    assert btn_1080.isChecked()


def test_search_filters_queue(window, images, qtbot):
    w = window
    add(w, images)
    qtbot.keyClick(w, Qt.Key.Key_F, Qt.KeyboardModifier.ControlModifier)
    assert w._search.hasFocus()
    qtbot.keyClicks(w._search, "png")
    assert len(rows(w)) == 2 and w._file_count.text() == "5 dosya (2 gösteriliyor)"
    w._search.clear()
    qtbot.keyClicks(w._search, "yok-boyle-dosya")
    texts = [w._queue_lay.itemAt(i).widget().text() for i in range(w._queue_lay.count())
             if isinstance(w._queue_lay.itemAt(i).widget(), QLabel)]
    assert texts == ["Sonuç bulunamadı"]
    w._search.clear()
    assert len(rows(w)) == 5


def test_select_row_and_delete(window, images, qtbot):
    w = window
    add(w, images / "kirmizi.png", images / "mavi.png")
    qtbot.mouseClick(rows(w)[1], Qt.MouseButton.LeftButton)
    assert w._selected == 1 and "mavi.png" in w._status_msg.text()
    w.setFocus()
    qtbot.keyClick(w, Qt.Key.Key_Delete)
    assert [Path(j.path).name for j in w._jobs] == ["kirmizi.png"]
    assert w._status_msg.text() == "Kaldırıldı: mavi.png"


def test_row_hover_is_cleared_on_leave(window, images, qtbot):
    w = window
    add(w, images / "kirmizi.png")
    row = rows(w)[0]
    plain = row.styleSheet()
    from PySide6.QtGui import QEnterEvent

    row.enterEvent(QEnterEvent(QPointF(5, 5), QPointF(5, 5), QPointF(5, 5)))
    assert row.styleSheet() != plain
    from PySide6.QtCore import QEvent

    row.leaveEvent(QEvent(QEvent.Type.Leave))
    assert row.styleSheet() == plain  # önceden vurgu kalıcıydı


def test_convert_all_then_remove_done(window, images, tmp_path, qtbot):
    w = window
    add(w, images / "kirmizi.png", images / "mavi.png", images / "yesil.jpg", images / "bozuk.jpg")
    w._fmt.setCurrentText("jpeg")
    qtbot.keyClick(w, Qt.Key.Key_Return, Qt.KeyboardModifier.ControlModifier)
    qtbot.waitUntil(lambda: not w._batch_running, timeout=15000)
    out = tmp_path / "Cikti"
    assert sorted(p.name for p in out.iterdir()) == ["kirmizi.jpg", "mavi.jpg", "yesil.jpg"]
    assert [j.status for j in w._jobs] == ["done", "done", "done", "error"]
    assert w._status_msg.text() == "Batch tamamlandı — 3 dosya, 1 hata"
    assert w._batch_frame.isHidden() and w._convert_btn.text() == "1 Dosyayı Dönüştür"
    assert w._fmt.isEnabled() and w._add_btn.isEnabled()

    retry = next(b for b in w.findChildren(QAbstractButton) if b.text() == "Hataları tekrarla")
    qtbot.mouseClick(retry, Qt.MouseButton.LeftButton)
    assert w._jobs[3].status == "pending" and "1 hatalı" in w._status_msg.text()

    done = next(b for b in w.findChildren(QAbstractButton) if b.text() == "Tamamlananları sil")
    qtbot.mouseClick(done, Qt.MouseButton.LeftButton)
    assert [Path(j.path).name for j in w._jobs] == ["bozuk.jpg"]
    assert w._status_msg.text() == "3 tamamlanan dosya silindi"


def _slow_batch(monkeypatch):
    """Dönüştürmeyi iptal edilene dek bekleten sahte convert_batch (zamanlamadan bağımsız iptal testi)."""
    from ui import main_window as mw

    started = threading.Event()

    def fake(sources, out, opts, *, on_file, on_progress, cancel_check):
        started.set()
        on_file(0, str(Path(out) / "x.webp"), None)
        on_progress(1, len(sources))
        while not cancel_check():
            threading.Event().wait(0.02)
        return ["x"], []

    monkeypatch.setattr(mw, "convert_batch", fake)
    return started


def test_escape_cancels_running_batch(window, images, dialogs, monkeypatch, qtbot):
    w = window
    _slow_batch(monkeypatch)
    add(w, images / "kirmizi.png", images / "mavi.png", images / "yesil.jpg")
    qtbot.mouseClick(w._convert_btn, Qt.MouseButton.LeftButton)
    qtbot.waitUntil(lambda: w._batch_bar.value() == 1, timeout=5000)
    assert w._batch_frame.isVisible() and not w._fmt.isEnabled() and not w._add_folder_btn.isEnabled()
    assert w._convert_btn.text() == "Dönüştürülüyor…"
    dialogs["answer"] = QMessageBox.StandardButton.No
    qtbot.keyClick(w, Qt.Key.Key_Escape)
    assert w._batch_running
    dialogs["answer"] = QMessageBox.StandardButton.Yes
    qtbot.mouseClick(w._cancel_btn, Qt.MouseButton.LeftButton)
    qtbot.waitUntil(lambda: not w._batch_running, timeout=5000)
    assert [j.status for j in w._jobs] == ["done", "cancelled", "cancelled"]
    assert w._status_msg.text().startswith("Batch iptal edildi")


def test_cancel_question_after_batch_finished_does_not_crash(window, images, dialogs, monkeypatch, qtbot):
    """Soru kutusu açıkken iş biterse 'Evet' None üzerinde cancel() çağırıyordu (AttributeError)."""
    w = window
    _slow_batch(monkeypatch)
    add(w, images / "kirmizi.png")
    w._start_convert()
    qtbot.waitUntil(lambda: w._batch_bar.value() == 1, timeout=5000)

    def finish_meanwhile():
        w._worker.cancel()
        qtbot.waitUntil(lambda: not w._batch_running, timeout=5000)

    dialogs["on_ask"] = finish_meanwhile
    w._cancel_convert()
    assert w._worker is None and not w._batch_running


def test_clear_queue_asks_first(window, images, dialogs, qtbot):
    w = window
    add(w, images / "kirmizi.png")
    clear = next(b for b in w.findChildren(QAbstractButton) if b.text() == "Kuyruğu temizle")
    dialogs["answer"] = QMessageBox.StandardButton.No
    qtbot.mouseClick(clear, Qt.MouseButton.LeftButton)
    assert len(w._jobs) == 1
    dialogs["answer"] = QMessageBox.StandardButton.Yes
    qtbot.mouseClick(clear, Qt.MouseButton.LeftButton)
    assert not w._jobs and w._drop.isVisible() and w._status_msg.text() == "Kuyruk temizlendi"


def test_output_folder_picker_and_overwrite_confirmation(window, images, dialogs, qtbot):
    w = window
    pick = next(b for b in w.findChildren(QAbstractButton) if b.objectName() == "FolderBtn")
    dialogs["folder"] = str(images)
    qtbot.mouseClick(pick, Qt.MouseButton.LeftButton)
    assert w._out_edit.text() == str(images) and w._output_dir == str(images)

    add(w, images / "kirmizi.png")
    w._fmt.setCurrentText("png")
    w._overwrite.setChecked(True)
    before = (images / "kirmizi.png").read_bytes()
    dialogs["answer"] = QMessageBox.StandardButton.No
    qtbot.mouseClick(w._convert_btn, Qt.MouseButton.LeftButton)
    assert dialogs["asked"] and dialogs["asked"][-1][0] == "Orijinallerin üzerine yazılacak"
    assert not w._batch_running and (images / "kirmizi.png").read_bytes() == before


def test_close_saves_settings(window):
    w = window
    w._fmt.setCurrentText("avif")
    w.close()
    assert w.saved and w.saved[-1]["fmt"] == "avif"


def test_every_control_has_accessible_name(window, images):
    w = window
    add(w, images / "kirmizi.png")
    missing = []
    for c in w.findChildren(QAbstractButton) + w.findChildren(QSlider) + w.findChildren(QComboBox) \
            + w.findChildren(QLineEdit):
        if isinstance(c.parent(), (QComboBox, QLineEdit)):  # Qt'nin iç düzenleyici / temizle düğmesi
            continue
        text = c.text().strip("…+ ■") if isinstance(c, QAbstractButton) else ""
        if not (c.accessibleName() or text):
            missing.append(c)
    assert not missing, missing
    assert rows(w)[0].accessibleName() == "kirmizi.png: Bekliyor"
    assert w._drop.accessibleName()
