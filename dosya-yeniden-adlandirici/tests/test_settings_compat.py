"""Eski sürüm ayar dosyası ve pencere duman testi (pencere açmadan, offscreen)."""
from __future__ import annotations

import json
from pathlib import Path


def test_old_settings_file_still_loads(tmp_path, monkeypatch):
    from core import settings as settings_mod

    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    base = tmp_path / ".local" / "share" / "DosyaYenidenAdlandirici"
    base.mkdir(parents=True)
    # 1.x biçimi: yeni anahtarlar eksik, artık kullanılmayan bir anahtar var
    (base / "settings.json").write_text(
        json.dumps({"last_folder": r"D:\Foto", "theme": "light", "eski_anahtar": 1}), encoding="utf-8"
    )
    s = settings_mod.SettingsStore.instance().settings
    assert (s.last_folder, s.theme, s.undo_stack_max) == (r"D:\Foto", "light", 20)


def test_adding_files_updates_label_and_preview(tmp_path, monkeypatch):
    from PySide6.QtWidgets import QApplication

    from core import settings as settings_mod

    monkeypatch.setenv("USERPROFILE", str(tmp_path / "home"))
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    settings_mod.SettingsStore.instance().settings.show_welcome = False
    from ui.main_window import MainWindow

    QApplication.instance() or QApplication([])
    (tmp_path / "a.txt").write_text("x", encoding="utf-8")
    win = MainWindow()
    win._ingest_paths([Path(tmp_path / "a.txt")])  # önceden ElideMiddle hatası burada patlıyordu
    win._refresh_preview()
    assert win.path_label.toolTip().startswith("1 dosya") and win.preview_stack.preview_table.rowCount() == 1
    win.close()


def test_focus_window_restores_minimized():
    """main.py açılışta çağırır; önceden int(WindowState) TypeError ile exe'yi çökertiyordu."""
    from PySide6.QtCore import Qt
    from PySide6.QtWidgets import QApplication, QWidget

    from ui.window_utils import focus_window

    QApplication.instance() or QApplication([])
    w = QWidget()
    w.setWindowState(Qt.WindowState.WindowMinimized)
    focus_window(w)
    assert not (w.windowState() & Qt.WindowState.WindowMinimized)
    w.close()
