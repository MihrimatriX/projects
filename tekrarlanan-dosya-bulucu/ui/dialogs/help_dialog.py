from PySide6.QtWidgets import QDialog, QLabel, QPushButton, QVBoxLayout

SHORTCUTS = (
    ("F5", "Taramayı başlat (seçili mod)"),
    ("Esc", "Taramayı iptal et"),
    ("Delete", "Seçili kopyaları sil · kök listesi odaktaysa kökü kaldır"),
    ("Ctrl+O", "Kök klasör ekle"),
    ("Ctrl+F", "Sonuçlarda yol ara"),
    ("Ctrl+,", "Ayarlar"),
    ("Ctrl+E", "JSON dışa aktar"),
    ("Ctrl+Shift+E", "CSV dışa aktar"),
    ("Ctrl+Shift+H", "HTML rapor"),
    ("F1", "Bu yardım"),
    ("Space / Enter", "Odaktaki grup kartını aç / kapat"),
)


class HelpDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Yardım")
        self.setMinimumSize(520, 480)
        layout = QVBoxLayout(self)
        rows = "".join(f"<tr><td><b>{k}</b></td><td>&nbsp;&nbsp;{v}</td></tr>" for k, v in SHORTCUTS)
        text = QLabel(
            f"<h3>Klavye kısayolları</h3><table>{rows}</table>"
            "<h3>İpuçları</h3>"
            "<p>Klasörleri pencereye sürükleyip bırakın. Kök listesinde sağ tık: Explorer'da aç / kaldır.<br>"
            "Dosyada sağ tık: göster, kopyala · ağaçta çift tık: aç.<br>"
            "pHash modu benzer görselleri bulur (Pillow + ImageHash gerekir).<br>"
            "120+ grupta otomatik kompakt liste; Enter veya çift tık grup detayını açar.<br>"
            "Araçlar menüsü: geçmiş, önbellek, oturum kaydet/yükle.<br>"
            "Disk Alanı Görselleştirici'deki «Tekrarlanan Dosya Bulucu'da aç» klasörleri buraya gönderir.<br>"
            "Zamanlanmış tarama: Ayarlar → gün aralığı (tepsi bildirimi).</p>"
        )
        text.setWordWrap(True)
        layout.addWidget(text)
        btn = QPushButton("Kapat")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
