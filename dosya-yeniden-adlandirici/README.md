# Dosya Yeniden Adlandırıcı

Kural zinciri ve canlı önizlemeyle dosyaları toplu, güvenli ve geri alınabilir şekilde yeniden adlandıran PySide6 masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler
- **Kurallar:** bul/değiştir (düz metin ya da regex, harf duyarlılığı), numaralandırma (önek/sonek, başlangıç, hane), büyük/küçük harf, uzantı değiştirme, EXIF / değiştirme tarihi; her kurala uzantı koşulu; sıra ↑ ↓, etkin/devre dışı.
- **Hazır setler ve makro:** 8 hazır kural seti; makro kaydet / çalıştır; kural setini JSON olarak kaydet / yükle.
- **Canlı önizleme:** çakışan ve Windows'a yasak adlar (`< > : " / | ? *`, ayrılmış adlar) işaretlenir ve uygulama engellenir; arama (`Ctrl+F`), yalnızca çakışmalar / yalnızca değişenler filtresi; büyük listelerde (varsayılan 80+) arka planda, iptal edilebilir hesaplama; CSV / JSON dışa aktarma.
- **Güvenlik:** hiçbir dosyanın üzerine yazılmaz (dolu hedefte işlem başlamadan iptal); yarıda hata olursa tüm adımlar geri alınır; harf değişimi, takas ve zincir adlandırmalar desteklenir.
- **Geri al / yinele:** çok adımlı `Ctrl+Z` (uygulama kapatılıp açılınca da çalışır) ve `Ctrl+Y`.
- **Arayüz:** sürükle-bırak, koyu/açık tema, dar pencerede alt alta yerleşim, tüm eylemler klavyeyle, ekran okuyucu adları.

## Hızlı başlangıç
| Ne | Komut |
|---|---|
| Hazır exe | `dist\dosya-yeniden-adlandirici\DosyaYenidenAdlandirici.exe` (repo kökünde; `_internal` ile birlikte taşıyın) |
| Kaynaktan çalıştır | `.\run.ps1` (`.venv` kurar, açık kalmış eski oturumu kapatır) |
| Testler | `.\run.ps1 -Check` (birim + entegrasyon, pencere açmaz) |
| Arayüz testleri | `.\run.ps1 -UiTest` (pytest-qt, gerçek pencereler) |
| Exe üretme | `.\publish.ps1` → `dist\dosya-yeniden-adlandirici\` (önce testleri çalıştırır; Linux/macOS: `publish.sh`) |
| Kurulum / kaldırma | `.\install.ps1` / `.\uninstall.ps1` |
| Ekran görüntüsü | `.\.venv\Scripts\python.exe scripts\ekran_goruntusu.py` (uydurma dosyalarla, ekranı kopyalamadan) |

## Kullanım
1. Dosyaları sürükleyin ya da `Ctrl+O` (dosya) / `Ctrl+Shift+O` (klasör).
2. Soldaki kural zincirini düzenleyin ya da hazır bir set seçin; önizleme anında güncellenir.
3. Çakışma varsa "Çakışmalar" filtresiyle bulun ve düzeltin; listeden çıkarmak için `Delete`.
4. "N Dosyayı Uygula" / `Ctrl+Enter` → onay. Beğenmezseniz `Ctrl+Z`.

| Kısayol | İşlev |
|---|---|
| `Ctrl+O` / `Ctrl+Shift+O` | Dosya ekle / klasör seç |
| `Ctrl+Enter` / `Ctrl+Shift+Enter` | Uygula (onaylı) / onaysız uygula |
| `Ctrl+Z` / `Ctrl+Y` (`Ctrl+Shift+Z`) | Geri al / yinele |
| `Ctrl+F` | Önizlemede ara |
| `Delete` | Seçili dosyaları listeden çıkar (diske dokunmaz) |
| `Ctrl+Shift+S` / `Ctrl+Shift+R` | Makro kaydet / çalıştır |
| `Ctrl+E` / `Ctrl+Shift+E` | Önizlemeyi CSV / JSON dışa aktar |
| `Ctrl+T` · `Ctrl+,` · `F1` · `Ctrl+Q` | Tema · Ayarlar · Yardım · Çıkış |

## Veri ve gizlilik
- `%USERPROFILE%\.local\share\DosyaYenidenAdlandirici\`: `settings.json` (ayarlar, son kurallar, makro, son klasör), `undo_history.json` (geri alma geçmişi). Konum ve anahtarlar önceki sürümlerle aynıdır; eski ayar dosyaları olduğu gibi okunur.
- `USERPROFILE` (Linux/macOS: `HOME`) bu kökü değiştirir; testler ve ekran görüntüsü betiği geçici klasör kullanır.
- Ağ erişimi yok, telemetri yok. Yinele geçmişi yalnızca oturum içinde tutulur.

## Mimari / analiz
- **Yığın:** Python 3.13, PySide6 6.11.2, Pillow 12.3 (EXIF; yoksa değiştirme tarihi kullanılır); PyInstaller 6.22.3 (onedir, windowed); test: pytest 9.1.1 + pytest-qt 4.5.0.
- **Klasörler:**
  ```
  main.py            tek örnek (mutex + mevcut pencereyi öne getirme)
  core/              rules_engine (önizleme, çakışma), rename_ops (hep-ya-hiç taşıma), undo_stack (geri al/yinele),
                     exif_meta, presets, macro, rules_io, settings
  ui/main_window.py  araç çubuğu, ☰ menü + kısayollar, önizleme, uygula / geri al / yinele, sürükle-bırak
  ui/widgets/        kural paneli (kartlar), önizleme tablosu, araç çubuğu; ui/workers/ arka plan önizleme
  ui/dialogs/        ayarlar, yardım, hakkında, hoş geldin
  scripts/           ekran_goruntusu.py
  tests/             birim/entegrasyon; tests/ui/ pytest-qt arayüz testleri
  ```
- **Veri akışı:** dosya listesi + kurallar → `compute_preview` (kurallar sırayla, uzantı koşulu, çakışma/yasak ad denetimi) → tablo → `apply_renames` (`_check_pairs` ön denetim → gerekirse iki aşamalı geçici ad → `os.rename`; hata olursa tam geri dönüş) → `UndoRecord` → `UndoStack` (JSON'a yazılır).
- **Kararlar:** yinele, geri almanın ters çiftleriyle aynı güvenli taşıma yolunu kullanır; tek tek eklenen dosyalarda klasör yeniden okunmaz (yalnızca yollar eşlenir); menü çubuğu gizli olduğu için kısayollu eylemler pencereye de eklenir.

## Testler
- `.\run.ps1 -Check`: 34 test — kural motoru, EXIF, güvenli adlandırma/geri alma/yinele, kural JSON, eski ayar dosyası uyumluluğu, pencere öne getirme, pencere duman testi.
- `.\run.ps1 -UiTest`: 33 pytest-qt testi — tüm menüler, kısayollar, kural paneli, önizleme, sürükle-bırak, diyaloglar. Envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası
- Kuralları sürükleyerek sıralama yok (↑ / ↓ düğmeleri).
- Yinele geçmişi uygulama kapanınca silinir (geri alma geçmişi kalıcıdır).
- Ağ sürücülerinde `os.rename` yarış penceresi: masaüstü tek kullanıcı için yeterli kabul edildi.
- Plan: kural önizlemesinde vurgulu fark, dosya ekleme filtresi (uzantı/desen).
