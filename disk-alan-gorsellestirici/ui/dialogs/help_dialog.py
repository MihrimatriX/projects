from PySide6.QtWidgets import QDialog, QLabel, QPushButton, QVBoxLayout


class HelpDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Yardım")
        self.setMinimumSize(460, 420)
        layout = QVBoxLayout(self)
        text = QLabel(
            "F5 — Tara · Shift+F5 — Önbelleği atlayarak tara\n"
            "Ctrl+O — Dizin seç · Ctrl+E — Dışa aktar · Ctrl+Q — Çık\n"
            "Ctrl+1 / Ctrl+2 — Sunburst / Treemap · Ctrl+B — Detay paneli\n"
            "Ctrl+D — Tekrar adayları · Ctrl+, — Ayarlar · F1 — Yardım\n"
            "Backspace — Üst klasör · Alt+Home — Köke dön\n"
            "Esc — Taramayı iptal et; tarama yoksa köke dön\n\n"
            "Grafik (Tab ile odaklanın):\n"
            "← → / ↑ ↓ — Segment seç · Enter — İçine gir\n"
            "Delete — Çöpe taşı · Menü tuşu / Shift+F10 — Sağ tık menüsü\n"
            "Fare: üzerine gel, tıkla (içine gir), sağ tık (Explorer, çöp, yeniden tara)\n\n"
            "Büyük dosyalar listesi: çift tık / Enter — Explorer · Delete — çöpe taşı\n"
            "Zaman makinesi — aynı klasörün son 4 taramasını karşılaştır\n"
            "Tekrar adayları — aynı boyutlu dosya grupları\n"
            "Dışa aktar: PNG, SVG, JSON, CSV, HTML"
        )
        text.setWordWrap(True)
        layout.addWidget(text)
        btn = QPushButton("Kapat")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
