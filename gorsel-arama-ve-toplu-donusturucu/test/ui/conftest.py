"""pytest-qt arayüz testleri: gerçek pencereler, geçici örnek görseller ve çıktı klasörü, sahte dosya
diyalogları / soru kutuları, ortak masaüstü kilidi. Kök conftest LOCALAPPDATA/USERPROFILE'ı geçiciye yönlendirir."""
from __future__ import annotations

import ctypes
import os
import time
from pathlib import Path

import pytest
from PIL import Image

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
def images(tmp_path) -> Path:
    """Örnek klasör: iki PNG, bir JPEG, alt klasörde bir JPEG, bozuk bir .jpg ve görsel olmayan dosya."""
    root = tmp_path / "Gorseller"
    (root / "Tatil").mkdir(parents=True)
    Image.new("RGB", (64, 48), "red").save(root / "kirmizi.png")
    Image.new("RGBA", (40, 40), (0, 0, 255, 128)).save(root / "mavi.png")
    Image.new("RGB", (3000, 2000), "green").save(root / "yesil.jpg", quality=80)
    Image.new("RGB", (32, 32), "white").save(root / "Tatil" / "plaj.jpg")
    (root / "bozuk.jpg").write_bytes(b"jpeg degil")
    (root / "notlar.txt").write_text("x", encoding="utf-8")
    return root


@pytest.fixture
def dialogs(monkeypatch):
    """QFileDialog / QMessageBox sahte: dönüş değerleri testte ayarlanır, çağrılar kaydedilir."""
    from PySide6.QtWidgets import QFileDialog, QMessageBox

    state = {"files": [], "folder": "", "answer": QMessageBox.StandardButton.Yes, "asked": [], "on_ask": None}

    def question(_parent, title, text, *a, **k):
        state["asked"].append((title, text))
        if state["on_ask"]:
            state["on_ask"]()
        return state["answer"]

    monkeypatch.setattr(QFileDialog, "getOpenFileNames", staticmethod(lambda *a, **k: (state["files"], "")))
    monkeypatch.setattr(QFileDialog, "getExistingDirectory", staticmethod(lambda *a, **k: state["folder"]))
    monkeypatch.setattr(QMessageBox, "question", staticmethod(question))
    return state


@pytest.fixture
def window(qtbot, tmp_path, monkeypatch, dialogs):
    from PySide6.QtWidgets import QApplication

    from ui import main_window as mw

    out = tmp_path / "Cikti"
    saved: list[dict] = []
    monkeypatch.setattr(mw, "load_settings", lambda: {"output_dir": str(out)})
    monkeypatch.setattr(mw, "save_settings", saved.append)
    w = mw.MainWindow()
    w.saved = saved
    qtbot.addWidget(w)
    w.resize(1280, 800)
    w.show()
    qtbot.waitExposed(w)
    w.activateWindow()
    # Pencere kısayolları yalnızca etkin pencerede tetiklenir
    qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
    yield w
    if w._worker and w._worker.isRunning():
        w._worker.cancel()
        w._worker.wait()
