"""pytest-qt arayüz testleri: gerçek pencereler, geçici veri klasörü, ortak masaüstü kilidi."""

import ctypes
import os
import time
from ctypes import wintypes
from pathlib import Path

import pytest

GUI_LOCK = Path(__file__).resolve().parents[3] / ".gui.lock"


def _acquire_gui_lock(timeout: float = 600.0):
    """Repo kökündeki .gui.lock'u paylaşımsız (FileShare.None) açar; diğer agent'lar bırakana dek bekler."""
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
def demo_root(tmp_path, monkeypatch):
    """Demo klasörü; ev dizini onun üstüne yönlendirilir ki yollar '~/Projeler/...' görünsün."""
    home = tmp_path / "home"
    root = home / "Projeler"
    (root / "rapor").mkdir(parents=True)
    (root / "kod").mkdir()
    (root / "rapor" / "yillik_rapor_2025.pdf").write_bytes(b"%PDF-1.4 demo")
    (root / "rapor" / "rapor_notlari.md").write_text("Toplanti ozeti ve butce", encoding="utf-8")
    (root / "kod" / "rapor_uret.py").write_text("print('rapor')", encoding="utf-8")
    (root / "kod" / "a&b_rapor.txt").write_text("x", encoding="utf-8")
    (root / "logo.png").write_bytes(b"\x89PNG\r\n")
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    from utils.settings import save_settings

    save_settings({"search_roots": [str(root)], "tantivy_primary": False})
    return root
