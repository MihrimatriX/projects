"""docs/ekran.png: uydurma örnek fotoğraflarla (sahte GPS/kamera EXIF), geçici ayar klasöründe, ekrana çıkmadan
(WA_DontShowOnScreen) çizilir. Kullanıcı verisine ve gerçek ayarlara dokunmaz.

Çalıştır:  .venv/Scripts/python.exe scripts/ekran_goruntusu.py
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = Path(tempfile.mkdtemp(prefix="metadata-demo-"))
for var in ("USERPROFILE", "HOME", "LOCALAPPDATA"):
    os.environ[var] = str(TMP)
sys.path.insert(0, str(ROOT))

from PIL import Image  # noqa: E402
from PySide6.QtCore import QCoreApplication, QEvent, Qt  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

GPS_IFD, EXIF_IFD = 0x8825, 0x8769
DEMO = [
    ("IMG_2041.jpg", "Apple", "iPhone 15 Pro", (38.6431, 34.8289), (220, 150, 90)),
    ("IMG_2042.jpg", "Apple", "iPhone 15 Pro", (38.6440, 34.8301), (90, 140, 210)),
    ("DSC_0193.jpg", "NIKON CORPORATION", "NIKON Z 6II", (41.0082, 28.9784), (70, 150, 90)),
    ("kahvalti.jpg", "samsung", "Galaxy S24", (39.9208, 32.8541), (240, 200, 120)),
    ("ekran_resmi.png", None, None, None, (40, 50, 70)),
]


def make_photo(path: Path, make, model, gps, color) -> None:
    img = Image.new("RGB", (1200, 900), color)
    if path.suffix == ".png":
        img.save(path)
        return
    exif = Image.Exif()
    exif[0x010F], exif[0x0110] = make, model
    exif[0x0131] = "Lightroom 13.2"
    exif[0x013B] = "Ayse Yilmaz"  # Artist (uydurma)
    exif[0x0132] = "2024:08:17 18:42:05"
    exif.get_ifd(EXIF_IFD)[0xA431] = "C02XK1ABJG5H"  # BodySerialNumber (uydurma)
    lat, lon = gps
    g = exif.get_ifd(GPS_IFD)
    g[1], g[2], g[3], g[4] = "N", (int(lat), int(lat % 1 * 60), 0.0), "E", (int(lon), int(lon % 1 * 60), 0.0)
    img.save(path, exif=exif.tobytes(), quality=85)


def main() -> None:
    src = TMP / "Fotograflar"
    src.mkdir()
    for name, make, model, gps, color in DEMO:
        make_photo(src / name, make, model, gps, color)

    app = QApplication(sys.argv)
    from ui import main_window as mw

    mw.MainWindow._setup_tray = lambda self: None  # tepside simge belirmesin
    w = mw.MainWindow()
    w.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    w.resize(1440, 960)
    w.show()
    w._on_paths_added([str(src / d[0]) for d in DEMO])
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    app.processEvents()

    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    w.grab().save(str(out / "ekran.png"))
    print(out / "ekran.png")


if __name__ == "__main__":
    main()
