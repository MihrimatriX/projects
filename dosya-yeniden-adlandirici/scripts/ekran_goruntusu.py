"""docs/ekran.png: uydurma dosyalarla, geçici
ev klasöründe, ekrana çıkmadan (WA_DontShowOnScreen) çizilir. Yol etiketi örnek bir yolla değiştirilir.

Çalıştır:  .venv/Scripts/python.exe scripts/ekran_goruntusu.py
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_home = tempfile.mkdtemp(prefix="dyad-demo-")
os.environ["USERPROFILE"] = _home
os.environ["HOME"] = _home
sys.path.insert(0, str(ROOT))

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtGui import QFont  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

DEMO_FILES = [f"IMG_{n:04d}.JPG" for n in (412, 413, 415, 420, 431, 432)] + [
    "Plaj Günü.jpg", "Akşam Yemeği.jpg", "notlar.txt", "rota haritası.pdf",
]
SHOWN_PATH = r"D:\Fotograflar\Tatil 2024"


def shot(w, path: Path) -> None:
    QApplication.processEvents()
    w._refresh_preview()
    w.path_label.setText(f"{len(w._files)} dosya · {SHOWN_PATH}")
    QApplication.processEvents()
    w.grab().save(str(path))


def main() -> None:
    app = QApplication(sys.argv)
    app.setFont(QFont("Segoe UI", 10))
    from core.models import CaseMode, Rule, RuleType
    from core.settings import SettingsStore
    from ui.main_window import MainWindow

    SettingsStore.instance().settings.show_welcome = False
    demo = Path(tempfile.mkdtemp(prefix="dyad-files-"))
    for name in DEMO_FILES:
        (demo / name).write_text("demo", encoding="utf-8")

    w = MainWindow()
    w.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen, True)
    w.resize(1280, 800)
    w.show()
    w._load_folder(demo)
    w.rules_panel.set_rules([
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="IMG_", replacement="Tatil_"),
        Rule(rule_type=RuleType.CASE, case_mode=CaseMode.LOWER, condition_ext="jpg"),
        Rule(rule_type=RuleType.NUMBERING, number_position="prefix", start=1, pad=3, separator="_"),
    ])
    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    shot(w, out / "ekran.png")

    print(out / "ekran.png")


if __name__ == "__main__":
    main()
