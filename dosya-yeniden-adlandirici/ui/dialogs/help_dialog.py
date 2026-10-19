from __future__ import annotations

from PySide6.QtWidgets import QDialog, QLabel, QVBoxLayout

HELP_TEXT = """
<h3>Hızlı başlangıç</h3>
<ol>
<li><b>Klasör seç</b> veya dosyaları sürükleyip bırakın.</li>
<li>Sol panelde <b>kural zincirini</b> düzenleyin; sırayı ↑ / ↓ düğmeleriyle değiştirin.</li>
<li><b>Yalnızca şu uzantılar</b> alanına <code>jpg,png</code> yazarak kuralı yalnızca o uzantılara uygulayın.</li>
<li>Sağdaki önizleme tablosunda sonuçları kontrol edin.</li>
<li><b>Uygula</b> — onaydan sonra yeniden adlandırma yapılır.</li>
</ol>
<h3>Kural türleri</h3>
<ul>
<li><b>Bul / Değiştir</b> — metin veya regex (Python re)</li>
<li><b>Numaralandır</b> — 001_ önek veya _001 sonek</li>
<li><b>Büyük / küçük harf</b> — dosya adı gövdesi</li>
<li><b>Uzantı</b> — örn. jpg → jpeg</li>
<li><b>EXIF tarih</b> — EXIF / mtime / <b>ikisi birleşik</b> ad modları</li>
</ul>
<h3>Kısayollar</h3>
<ul>
<li><b>Ctrl+O</b> / <b>Ctrl+Shift+O</b> — dosya ekle / klasör seç</li>
<li><b>Ctrl+Z</b> / <b>Ctrl+Y</b> — geri al (çok adımlı, kalıcı) / yinele</li>
<li><b>Ctrl+F</b> — önizlemede ara · <b>Delete</b> — seçili dosyaları listeden çıkar</li>
<li><b>Ctrl+Enter</b> — uygula (onaylı) · <b>Ctrl+Shift+Enter</b> — onaysız uygula</li>
<li><b>Ctrl+Shift+S</b> / <b>Ctrl+Shift+R</b> — makro kaydet / çalıştır</li>
<li><b>Ctrl+E</b> / <b>Ctrl+Shift+E</b> — önizlemeyi CSV / JSON dışa aktar</li>
<li><b>Ctrl+T</b> — tema · <b>Ctrl+,</b> — ayarlar · <b>F1</b> — yardım · <b>Ctrl+Q</b> — çıkış</li>
</ul>
<p><b>Dosya → Kuralları JSON</b> ile kural setini paylaşabilir veya yedekleyebilirsiniz.</p>
<p>Büyük listelerde <b>Önizleme iptal</b> ile hesaplamayı durdurabilirsiniz. Önizleme başlığındaki arama kutusu (Ctrl+F) eski ve yeni adlarda arar.</p>
"""


class HelpDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Yardım")
        self.setMinimumSize(500, 460)
        layout = QVBoxLayout(self)
        label = QLabel(HELP_TEXT)
        label.setWordWrap(True)
        label.setOpenExternalLinks(True)
        layout.addWidget(label)
