"""pytest-qt arayüz testleri: gerçek pencereler, geçici ev klasörü (ayar + geri alma geçmişi),
yalnızca tmp_path altındaki dosyaları yeniden adlandırır, ortak masaüstü kilidi."""
from __future__ import annotations

import ctypes
import os
import time
from pathlib import Path

import pytest

GUI_LOCK = Path(__file__).resolve().parents[3] / ".gui.lock"


def _acquire_gui_lock(timeout: float = 600.0):
    """Repo kökündeki .gui.lock'u paylaşımsız (FileShare.None) açar; diğer agent'lar bırakana dek bekler."""
    from ctypes import wintypes

    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.CreateFileW.restype = wintypes.HANDLE
    k32.CreateFileW.argtypes = [
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
        wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
    ]
    generic_rw, open_always, invalid = 0xC0000000, 4, wintypes.HANDLE(-1).value
    deadline = time.monotonic() + timeout
    while True:
        handle = k32.CreateFileW(str(GUI_LOCK), generic_rw, 0, None, open_always, 0x80, None)
        if handle != invalid:
            return k32, handle
        if time.monotonic() > deadline:
            raise TimeoutError(f"{GUI_LOCK} kilidi alınamadı")
        time.sleep(0.5)


@pytest.fixture(scope="session", autouse=True)
def gui_lock():
    # Offscreen'de ekrana bir şey çıkmaz; kilit yalnızca gerçek pencerelerde gerekir.
    if os.environ.get("QT_QPA_PLATFORM") == "offscreen" or os.name != "nt":
        yield
        return
    k32, handle = _acquire_gui_lock()
    try:
        yield
    finally:
        k32.CloseHandle(handle)


@pytest.fixture
def store(tmp_path, monkeypatch):
    """Her test boş bir ev klasörüyle başlar (settings.json + undo_history.json orada)."""
    from core import settings as settings_mod

    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("USERPROFILE", str(home))
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    st = settings_mod.SettingsStore.instance()
    st.settings.show_welcome = False
    st.save()
    return st


@pytest.fixture
def folder(tmp_path) -> Path:
    root = tmp_path / "Fotolar"
    root.mkdir()
    for name in ("Tatil Foto 1.jpg", "Tatil Foto 2.jpg", "Tatil Foto 3.jpg", "notlar.txt"):
        (root / name).write_text(name, encoding="utf-8")
    return root


@pytest.fixture
def make_window(qtbot, store):
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    windows = []

    def _make():
        w = MainWindow()
        qtbot.addWidget(w)
        w.resize(1200, 760)
        w.show()
        qtbot.waitExposed(w)
        w.activateWindow()
        qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
        windows.append(w)
        return w

    yield _make
    for w in windows:
        if w._preview_worker and w._preview_worker.isRunning():
            w._preview_worker.cancel()
            w._preview_worker.wait(3000)
