"""docs/ekran.png: uydurma örnek görsellerle, geçici veri klasöründe, ekrana çıkmadan (WA_DontShowOnScreen)
çizilir. Gerçek kullanıcı yolu görünmez (çıktı klasörü örnek bir yol olarak gösterilir, oluşturulmaz).

Çalıştır:  .venv/Scripts/python.exe scripts/ekran_goruntusu.py
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = Path(tempfile.mkdtemp(prefix="gorsel-demo-"))
os.environ["LOCALAPPDATA"] = str(TMP)
sys.path.insert(0, str(ROOT))

from PIL import Image, ImageChops  # noqa: E402
from PySide6.QtCore import QCoreApplication, QEvent, Qt  # noqa: E402
from PySide6.QtGui import QFont  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

# (ad, boyut, iki renk, durum)
DEMO = [
    ("gunbatimi_kapadokya.jpg", (4032, 3024), ((255, 140, 60), (90, 40, 120)), "done"),
    ("deniz_kenari.jpg", (4032, 3024), ((40, 150, 220), (230, 220, 170)), "done"),
    ("orman_yuruyusu.png", (2400, 1600), ((40, 120, 60), (190, 220, 120)), "done"),
    ("logo_seffaf.png", (800, 800), ((240, 190, 110), (30, 40, 60)), "processing"),
    ("urun_fotografi_01.jpg", (3000, 3000), ((230, 230, 235), (120, 130, 150)), "pending"),
    ("urun_fotografi_02.jpg", (3000, 3000), ((250, 220, 200), (160, 90, 80)), "pending"),
    ("ekran_kaydi.webp", (1920, 1080), ((30, 30, 40), (90, 200, 250)), "pending"),
    ("eski_tarama.tif", (2480, 3508), ((210, 200, 180), (120, 100, 80)), "pending"),
]


def make_image(path: Path, size, c1, c2) -> None:
    w, h = 320, 240  # küçük çiz, sonra büyüt (hızlı)
    mask = ImageChops.add(Image.linear_gradient("L").resize((w, h)),
                          Image.radial_gradient("L").resize((w, h)), scale=2.0)
    img = Image.composite(Image.new("RGB", (w, h), c1), Image.new("RGB", (w, h), c2), mask)
    img.resize(size).save(path)


def main() -> None:
    src = TMP / "Fotograflar"
    src.mkdir()
    for name, size, (c1, c2), _ in DEMO:
        make_image(src / name, size, c1, c2)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setFont(QFont("Segoe UI Variable", 10))
    from ui.main_window import MainWindow

    w = MainWindow()
    w._output_dir = r"D:\Fotograflar\donusturulen"
    w._out_edit.setText(w._output_dir)
    w.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    w.resize(1280, 800)
    w.show()
    w._add_paths([str(src / d[0]) for d in DEMO])
    opts = w._current_options()
    from utils.image_convert import format_meta

    for job, (_, _, _, status) in zip(w._jobs, DEMO):
        job.status = status
        if status == "done":
            job.meta = format_meta(job.path, opts)
    w._selected = 4
    w._batch_running = True
    w._batch_frame.setVisible(True)
    w._batch_bar.setMaximum(8)
    w._batch_bar.setValue(3)
    w._batch_label.setText("Dönüştürülüyor… 3 / 8")
    w._batch_eta.setText("~6 sn kaldı")
    w._sync_ui()
    w._status_msg.setText("Dönüştürülüyor…")
    # Önceki çizimlerden deleteLater bekleyen satırları gerçekten sil
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    app.processEvents()

    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    w.grab().save(str(out / "ekran.png"))
    w._batch_running = False
    print(out / "ekran.png")


if __name__ == "__main__":
    main()
