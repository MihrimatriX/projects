"""pytest-qt arayüz testleri: gerçek pencereler, geçici veri klasörü (kök conftest LOCALAPPDATA'yı
yönlendirir), geçici örnek ağaç, sahte çöp kutusu / Explorer / Tekrarlanan köprüsü, ortak masaüstü kilidi."""
from __future__ import annotations

import ctypes
import os
import shutil
import time
from pathlib import Path

import pytest

GUI_LOCK = Path(__file__).resolve().parents[3] / ".gui.lock"
MB = 1024 * 1024


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


def _sized(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.truncate(size)  # içerik yazmadan boyut ver (hızlı)


@pytest.fixture
def tree(tmp_path) -> Path:
    """Örnek klasör: büyük dosya, aynı boyutlu iki dosya, temizlik önerisi (node_modules), boş klasör."""
    root = tmp_path / "Ornek"
    _sized(root / "Videolar" / "film.mkv", 150 * MB)
    _sized(root / "Videolar" / "klip.mp4", 3 * MB)
    _sized(root / "Yedek" / "klip-kopya.mp4", 3 * MB)
    _sized(root / "node_modules" / "paket" / "index.js", 2 * MB)
    _sized(root / "Belgeler" / "rapor.pdf", 40 * 1024)
    (root / "Bos").mkdir()
    return root


@pytest.fixture
def store(tmp_path, monkeypatch):
    """Her test temiz ayar dosyasıyla başlar (tekrar adayı alt sınırı 1 MB)."""
    from core import settings as settings_mod

    monkeypatch.setattr(settings_mod, "SETTINGS_PATH", tmp_path / "settings.json")
    monkeypatch.setattr(settings_mod.SettingsStore, "_instance", None)
    st = settings_mod.SettingsStore.instance()
    st.settings.min_duplicate_size_mb = 1
    st.settings.first_run_completed = True
    return st


@pytest.fixture
def fakes(monkeypatch, tmp_path):
    """Explorer açma ve çöpe taşıma sahte: yalnızca tmp_path altındaki öğeleri siler."""
    from ui import main_window as mw

    calls = {"reveal": [], "trash": []}

    def fake_trash(path: str) -> None:
        p = Path(path).resolve()
        assert tmp_path.resolve() in p.parents, f"test dışı yol: {p}"
        calls["trash"].append(str(p))
        shutil.rmtree(p) if p.is_dir() else p.unlink()

    monkeypatch.setattr(mw, "reveal_in_explorer", lambda p: calls["reveal"].append(p))
    monkeypatch.setattr(mw, "move_to_trash", fake_trash)
    return calls


@pytest.fixture
def make_window(qtbot, store, fakes):
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    windows = []

    def _make(root: Path | None = None):
        w = MainWindow()
        if root is not None:
            w._scan_root = str(root)
        qtbot.addWidget(w)
        w.resize(1280, 800)
        w.show()
        qtbot.waitExposed(w)
        w.activateWindow()
        # Pencere kısayolları yalnızca etkin pencerede tetiklenir
        qtbot.waitUntil(lambda: QApplication.activeWindow() is w, timeout=3000)
        windows.append(w)
        return w

    yield _make
    for w in windows:
        w._schedule_timer.stop()
        w._cancel_scan()
