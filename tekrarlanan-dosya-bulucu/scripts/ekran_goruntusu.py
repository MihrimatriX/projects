"""docs/ekran.png + docs/ekran-silme.png: örnek (uydurma) gruplarla, geçici veri klasöründe, ekrana çıkmadan.

Çalıştır:  .venv/Scripts/python.exe scripts/ekran_goruntusu.py
"""

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ["TEKRARLANAN_DATA_DIR"] = tempfile.mkdtemp(prefix="tekrarlanan-demo-")
sys.path.insert(0, str(ROOT))

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

KB, MB = 1024, 1024 * 1024
DEMO = [  # (boyut, [yollar]) — gerçek kullanıcı yolu yok
    (48 * MB, [r"D:\Videolar\tatil_2024.mp4", r"E:\Yedek\Videolar\tatil_2024.mp4"]),
    (6 * MB, [r"D:\Fotograflar\2024\IMG_0412.jpg", r"D:\Fotograflar\Secilenler\IMG_0412.jpg", r"E:\Yedek\Fotograflar\IMG_0412.jpg"]),
    (2 * MB, [r"D:\Belgeler\sozlesme_imzali.pdf", r"D:\Indirilenler\sozlesme_imzali (1).pdf"]),
    (900 * KB, [r"D:\Belgeler\sunum_q3.pptx", r"E:\Yedek\Belgeler\sunum_q3.pptx"]),
    (320 * KB, [r"D:\Muzik\albüm\03-parca.mp3", r"D:\Indirilenler\03-parca.mp3"]),
]


def main() -> None:
    app = QApplication(sys.argv)
    from ui.dialogs.delete_confirm_dialog import DeleteConfirmDialog
    from ui.main_window import MainWindow
    from utils.duplicates import marked_for_deletion, total_wasted_bytes
    from utils.formatters import human_size
    from utils.models import DuplicateFile, DuplicateGroup

    groups = [
        DuplicateGroup(
            hash_hex=f"{i:02x}" * 32,
            size=size,
            files=[DuplicateFile(path=p, size=size, mtime=1_700_000_000 + n) for n, p in enumerate(paths)],
        )
        for i, (size, paths) in enumerate(DEMO, start=0x3a)
    ]
    w = MainWindow(initial_roots=[r"D:\Fotograflar", r"D:\Belgeler", r"E:\Yedek"])
    w.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    w.resize(1280, 800)
    w.show()
    w._all_groups = groups
    w._apply_keep()
    wasted = total_wasted_bytes(groups)
    w.savings_banner.set_stats(wasted, len(groups), sum(g.count - 1 for g in groups))
    w.savings_banner.show()
    w._render_groups()
    w._update_delete_button()
    w.scan_status.setText(f"{len(groups)} grup — {human_size(wasted)} kazanç potansiyeli")
    w.statusBar().showMessage("SHA-256 · 2 aşamalı doğrulama · F5 tara · Delete sil · Esc iptal")
    app.processEvents()

    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    w.grab().save(str(out / "ekran.png"))

    paths = marked_for_deletion(groups)
    dlg = DeleteConfirmDialog(paths, sum(f.size for g in groups for f in g.files if f.marked_for_delete))
    dlg.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    dlg.setStyleSheet(w.styleSheet())
    dlg.show()
    app.processEvents()
    dlg.grab().save(str(out / "ekran-silme.png"))
    w._schedule_timer.stop()
    print(out / "ekran.png")


if __name__ == "__main__":
    main()
