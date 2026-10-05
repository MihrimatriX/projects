"""pytest-qt arayüz testleri: gerçek pencereler, geçici veri klasörü, ortak masaüstü kilidi."""

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


def make_dupes(root: Path, groups: int, copies: int = 2, folders=("Fotograflar", "Yedek")) -> Path:
    """Her grup için `copies` adet aynı içerikli (>=1 KB) dosya üretir."""
    for g in range(groups):
        data = (f"grup-{g:03d} " * 200).encode()
        for c in range(copies):
            folder = root / folders[c] if c < len(folders) else root / folders[-1] / f"kopya{c}"
            folder.mkdir(parents=True, exist_ok=True)
            (folder / f"dosya_{g:03d}.txt").write_bytes(data)
    return root


@pytest.fixture
def store(tmp_path, monkeypatch):
    """Her test temiz ayar + geçmiş + önbellek dosyasıyla başlar."""
    from utils import scan_cache, scan_history
    from utils import settings as settings_mod

    data = tmp_path / "appdata"
    data.mkdir()
    monkeypatch.setattr(settings_mod, "SETTINGS_PATH", data / "settings.json")
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    monkeypatch.setattr(scan_history, "HISTORY_PATH", data / "scan_history.json")
    monkeypatch.setattr(scan_cache, "DB_PATH", data / "scan_cache.db")
    return settings_mod.SettingsStore.instance()


@pytest.fixture
def make_window(qtbot, store):
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    windows = []

    def _make(**kwargs):
        w = MainWindow(**kwargs)
        qtbot.addWidget(w)
        w.show()
        qtbot.waitExposed(w)
        w.activateWindow()
        # QShortcut'lar (F5, Ctrl+E…) yalnızca etkin pencerede tetiklenir
        qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
        windows.append(w)
        return w

    yield _make
    for w in windows:
        w._schedule_timer.stop()
        if w._worker and w._worker.isRunning():
            w._worker.cancel()
            w._worker.wait(5000)
