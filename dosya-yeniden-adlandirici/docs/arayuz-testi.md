# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (pytest-qt, gerçek Windows pencereleri, `tests/ui/`, 33 test).
Testler `USERPROFILE`'ı geçici klasöre yönlendirir (ayar + geri alma geçmişi orada) ve yalnızca `tmp_path`
altındaki dosyaları yeniden adlandırır. Masaüstü ortak kilidi (`..\.gui.lock`) test oturumu boyunca tutulur.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Açılış (exe / `run.ps1`) | Pencereyi öne getirme | Ana pencere açılır | **Düzeltildi** | `int(WindowState)` TypeError: exe ana pencere yerine hata kutusu gösteriyordu |
| Ana pencere | Dosya ekleme (araç çubuğu, `Ctrl+O`, sürükle-bırak) | Liste + önizleme | **Düzeltildi** | `Qt.TextElideMode.Middle` PySide6'da yok: her eklemede hata, önizleme hiç yenilenmiyordu |
| Ana pencere | Klasör seç (`Ctrl+Shift+O`, boş durum düğmesi) | Klasör yüklenir, son klasör kaydedilir | **Düzeltildi** | Boş durumda klasör düğmesi ve kısayol yoktu |
| Önizleme | Uygula / `Ctrl+Enter` / `Ctrl+Shift+Enter` | Onay (Hayır'da dokunmaz) / onaysız | Geçti | |
| Önizleme | Geri al `Ctrl+Z` / Yinele `Ctrl+Y`, `Ctrl+Shift+Z` | Diskte geri alır / yeniden uygular | **Eklendi** | Yinele yoktu |
| Önizleme | Tek tek eklenen dosyalarda geri al | Liste aynı dosyalarla kalır | **Düzeltildi** | Tüm klasör listeye doluyordu |
| Önizleme | Kalıcı geri alma (yeniden açınca) | Çalışır | Geçti | |
| Önizleme | Çakışma: sayaç, filtre düğmesi, uygula engeli | Uyarı, disk değişmez | Geçti | |
| Önizleme | Arama (`Ctrl+F`) | Eski/yeni adda süzer | **Düzeltildi** | Yardım vaat ediyordu, kutu yoktu |
| Önizleme | `Delete` (çoklu seçim, arama açıkken) / sağ tık menüsü | Yalnızca listeden çıkarır; menü imleçteki satıra göre | **Düzeltildi** | Tek seçim vardı; sağ tık "geçerli" satırı kullanıyordu |
| Önizleme | Kural alanında `Delete` | Metni siler, listeye dokunmaz | Geçti | |
| Önizleme | CSV / JSON dışa aktar (düğmeler, `Ctrl+E`, `Ctrl+Shift+E`) | Dosya yazılır | Geçti | |
| Önizleme | Arka plan önizleme ilerleme + İptal | İlerleme çubuğu, "Önizleme iptal edildi" | Geçti | |
| Kural paneli | Kart ekle / tip / ↑ ↓ / ✕ / etkin kutusu | Önizleme güncellenir | **Düzeltildi** | Aynı alanlı iki kuralda yanlış kart taşınıyor/siliniyordu; ↓ ✕ düğmeleri kart taşınca kırpılıyordu; erişilebilir adlar |
| Kural paneli | Regex hatası | Kartta hata, uygula kapalı | Geçti | |
| Kural paneli | EXIF modu | Türkçe seçenekler | **Düzeltildi** | Ham enum adları (`EXIF_OR_MTIME`) görünüyordu; "sürükleyerek sıralayın" vaadi kaldırıldı |
| Kural paneli | Hazır setler (8 düğme) | Kuralları değiştirir | **Düzeltildi** | "EXIF Rename", "Makro: Temizle" etiketleri |
| Makro | `Ctrl+Shift+S` / `Ctrl+Shift+R` | Kaydet / geri yükle; yoksa bilgi | Geçti | |
| ☰ menü | Dosya / Düzen / Görünüm / Yardım | Tüm eylemler kısayollu | **Düzeltildi** | Menü kısayolları yoktu; açık temada ☰ simgesi görünmüyordu |
| ☰ menü | Kuralları JSON kaydet / yükle (bozuk dosya) | Gidiş-dönüş; bozukta hata | Geçti | |
| Tema | `Ctrl+T`, ay/güneş düğmesi | Kalıcı | Geçti | |
| Ayarlar (`Ctrl+,`) | Tema, yalnızca değişenler, geri al sınırı; İptal | Uygulanır / değişmez | Geçti | |
| Yardım (`F1`), Hakkında, Hoş geldin | Adımlar, Atla, nokta düğmeleri | Kapanır; ilk açılışta bir kez | Geçti | Nokta düğmelerine erişilebilir ad |
| Dar pencere (< 900 px) | Yerleşim | Paneller alt alta | Geçti | |
| Kapatma (`Ctrl+Q`) | Kurallar, son klasör | `%USERPROFILE%\.local\share\DosyaYenidenAdlandirici\settings.json` (aynı anahtarlar) | Geçti | |
