"""docs/ekran.png + docs/ekran-treemap.png + docs/ekran-tekrar.png: uydurma örnek ağaçla, geçici veri
klasöründe, ekrana çıkmadan (WA_DontShowOnScreen) çizilir. Gerçek kullanıcı yolu görünmez.

Çalıştır:  .venv/Scripts/python.exe scripts/ekran_goruntusu.py
"""
from __future__ import annotations

import os
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ["LOCALAPPDATA"] = tempfile.mkdtemp(prefix="disk-alan-demo-")
sys.path.insert(0, str(ROOT))

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

MB, GB = 1024**2, 1024**3
BASE = r"D:\Arsiv"
# (klasör, [(dosya, boyut)])
DEMO = {
    "Videolar": [("tatil_2024.mkv", int(9.4 * GB)), ("dugun.mp4", int(6.1 * GB)), ("sunum_kaydi.mp4", 2 * GB)],
    "Fotograflar": [("2023.zip", int(3.2 * GB)), ("IMG_0412.heic", 4 * MB)] + [(f"IMG_{i:04d}.jpg", 6 * MB) for i in range(40)],
    "Projeler": [("node_modules", int(2.6 * GB)), ("build", 900 * MB), ("kaynak.zip", 400 * MB)],
    "Oyunlar": [("kurulum.iso", int(7.8 * GB))],
    "OneDrive": [("yedek.7z", int(3.9 * GB)), ("rapor_q3.pdf", 12 * MB)],
    "Belgeler": [("tez.docx", 30 * MB), ("butce.xlsx", 4 * MB), ("sozlesme.pdf", 2 * MB)],
    "Muzik": [(f"parca_{i:02d}.mp3", 9 * MB) for i in range(60)],
    "Indirilenler": [("dugun.mp4", int(6.1 * GB)), ("setup.exe", 180 * MB)],
}


def build_tree():
    from core.categorizer import categorize
    from core.models import ScanNode

    dirs = []
    for folder, files in DEMO.items():
        fpath = f"{BASE}\\{folder}"
        kids = []
        for name, size in files:
            path = f"{fpath}\\{name}"
            is_dir = "." not in name
            kids.append(ScanNode(name, path, size, 1 if not is_dir else 800, is_dir, categorize(path, is_dir=is_dir)))
        dirs.append(ScanNode(folder, fpath, sum(k.size for k in kids), sum(k.file_count for k in kids), True,
                             categorize(fpath, is_dir=True), kids))
    return ScanNode("Arsiv", BASE, sum(d.size for d in dirs), sum(d.file_count for d in dirs), True, "default", dirs)


def add_history(root) -> None:
    """Zaman makinesi için üç eski tarama (boyut büyüyerek)."""
    from core.cache import DB_PATH
    from core.history import append_history

    for days, factor in ((90, 0.78), (60, 0.86), (30, 0.93), (0, 1.0)):
        sid = append_history(BASE, root)
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute(
                "UPDATE scan_history SET scanned_at = date('now', ?), total_size = ? WHERE id = ?",
                (f"-{days} day", int(root.size * factor), sid),
            )


def main() -> None:
    app = QApplication(sys.argv)
    from core.scanner import large_files_in
    from core.settings import SettingsStore
    from ui.dialogs.duplicates_dialog import DuplicatesDialog
    from ui.main_window import MainWindow

    SettingsStore.instance().settings.min_duplicate_size_mb = 10
    root = build_tree()
    add_history(root)
    w = MainWindow()
    w._schedule_timer.stop()
    w.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    w.resize(1280, 800)
    w.show()
    w._scan_root = BASE
    w._on_scan_done(root, large_files_in(root))
    w.state_banner.hide_banner()
    w.sunburst._kb_select(next(s for s in w.sunburst._segments if s.node.name == "Videolar"))
    app.processEvents()

    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    w.grab().save(str(out / "ekran.png"))

    w._set_view(1)
    w._navigate_to(next(c for c in root.children if c.name == "Projeler"))
    app.processEvents()
    w.grab().save(str(out / "ekran-treemap.png"))

    dlg = DuplicatesDialog(w._duplicates, w)
    dlg.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    dlg.setStyleSheet(w.styleSheet())
    dlg.show()
    app.processEvents()
    dlg.grab().save(str(out / "ekran-tekrar.png"))
    print(out / "ekran.png")


if __name__ == "__main__":
    main()
