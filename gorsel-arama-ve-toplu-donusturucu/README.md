# Görsel Arama ve Toplu Dönüştürücü

Görselleri kuyruğa toplayıp tek seferde WebP / JPEG / PNG / AVIF'e dönüştüren, küçülten ve metadata'sını
temizleyen PySide6 masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Kuyruk**
- Dosya ekleme (`Ctrl+O`, "+ Ekle", bırakma alanına tıklama / `Enter`), klasör ekleme (`Ctrl+Shift+O`,
  "+ Klasör"; alt klasörler dahil) ve sürükle-bırak
- Küçük resimli satırlar, durum rozeti (Bekliyor / İşleniyor / Tamam / Hata / İptal), boyut önizlemesi
  (`4032×3024 → 1920×1440`)
- Dosya adına göre arama (`Ctrl+F`), seçili satırı kaldırma (`Del`), hataları tekrarla, tamamlananları sil,
  kuyruğu temizle (onaylı)

**Dönüştürme**
- Çıktı: WebP, JPEG, PNG, AVIF; kalite, max genişlik/yükseklik ön ayarları (yalnızca küçültür)
- Codec ayarları: WebP method / kayıpsız, JPEG progressive / optimize / subsampling, PNG sıkıştırma / optimize
- EXIF yönüne göre döndürme (Orientation etiketi düşülür), gri ton, klasör yapısını koruma
- Metadata: kapalıyken EXIF çıktıya kopyalanır; "Metadata temizle" EXIF/GPS'i siler. Renk profili (ICC) korunur
- Şeffaf görseller JPEG'de beyaz zemine düzleştirilir; CMYK ve 16 bit girdiler desteklenir
- Arka plan iş parçacığı, ilerleme çubuğu + kalan süre, `Esc` ile onaylı iptal (kısmi çıktılar korunur)

**Güvenlik**
- Orijinaller asla ezilmez: aynı adlı çıktı varsa `ad (1).uzantı` üretilir. "Aynı adlı dosyaların üzerine yaz"
  seçilirse ve orijinal etkileniyorsa ayrıca onay sorulur. Kayıt geçici dosya + atomik taşıma ile yapılır
- Ayarlar kapanışta kaydedilir, açılışta geri yüklenir (bozuk ayar dosyası yok sayılır)

## Hızlı başlangıç

| Yol | Komut |
|---|---|
| Exe | `dist\gorsel-arama-ve-toplu-donusturucu\GorselDonusturucu.exe` (repo kökünde; `_internal` klasörüyle birlikte taşıyın) |
| Kaynaktan | `.\run.ps1` (ilk çalıştırmada `.venv` kurar) |
| Birim testleri | `.\run.ps1 -Check` (pencere açmaz) |
| Arayüz testleri | `.\run.ps1 -UiTest` (pytest-qt, gerçek pencereler, geçici veri) |
| Exe üretme | `.\publish.ps1` → `dist\gorsel-arama-ve-toplu-donusturucu\` |

Gereksinim: Python 3.11+ (3.13 önerilir). HEIC girdisi için ek Pillow eklentisi gerekir; yoksa o dosyalar
"Hata" olarak işaretlenir.

## Kullanım

1. Görselleri ekleyin (sürükle-bırak, `Ctrl+O` veya `Ctrl+Shift+O`).
2. Soldan format, boyut ve kaliteyi seçin; satırlardaki boyut önizlemesi anında güncellenir.
3. Çıktı klasörünü "…" ile seçin (varsayılan `~/Pictures/converted`).
4. "N Dosyayı Dönüştür" veya `Ctrl+Enter`. Bitince hatalı dosyaları "Hataları tekrarla" ile yeniden deneyin.

| Kısayol | İşlev |
|---|---|
| `Ctrl+O` | Dosya ekle |
| `Ctrl+Shift+O` | Klasör ekle |
| `Ctrl+Enter` | Dönüştürmeyi başlat |
| `Esc` | Dönüştürmeyi iptal et (onaylı) |
| `Del` | Seçili dosyayı kuyruktan kaldır |
| `Ctrl+F` | Aramaya odaklan |
| `Enter` / `Space` | Bırakma alanı odaktayken dosya seç |

## Veri ve gizlilik

- Ayarlar: `%LOCALAPPDATA%\gorsel-arama-ve-toplu-donusturucu\settings.json` (`LOCALAPPDATA` ortam
  değişkeniyle yönlendirilebilir; testler geçici klasör kullanır).
- Uygulama yalnızca seçtiğiniz dosyaları okur ve seçtiğiniz çıktı klasörüne yazar.
- Ağ erişimi yok; telemetri yok.

## Mimari / analiz

- **Yığın:** Python 3.13, PySide6 6.11, Pillow 12.3; test: pytest 9, pytest-qt 4.5; paket: PyInstaller 6.22
  (onedir, windowed, `GorselDonusturucu.spec`).
- **Klasörler:**
  - `main.py` — uygulama, yazı tipi, ikon
  - `ui/main_window.py` — pencere, kuyruk (`Job`, `JobRow`), bırakma alanı, `ConvertWorker` (QThread)
  - `ui/theme.py` — koyu tema stil sayfası, rozet renkleri
  - `utils/image_convert.py` — toplama, boyut hesabı, hedef yol / ad çakışması, Pillow kaydı
  - `utils/convert_options.py` — `ConvertOptions` veri sınıfı; `utils/config.py` — sabitler + ayar dosyası
  - `scripts/ekran_goruntusu.py` — `docs/ekran.png`'yi uydurma görsellerle ekrana çıkmadan üretir
- **Veri akışı:** ekleme → `collect_images` (çözülmüş yollar, tekrar yok) → `Job` listesi → başlatınca
  `ConvertOptions` anlık görüntüsü + kaynak listesi `ConvertWorker`'a verilir → `convert_batch` dosya başına
  sinyal yollar → GUI iş parçacığı `Job` durumunu günceller.
- **Kararlar:** `Job` listesi yalnızca GUI iş parçacığında değişir; çalışan iş sırasında ayar/kuyruk
  kontrolleri kilitlenir; kapanışta çalışan iş iptal edilip beklenir (QThread çökmesi olmaz); küçük resimler
  `QImageReader` ile ölçeklenerek okunur ve önbelleklenir (her yeniden çizimde tam görsel okunmaz).

## Testler

| Paket | Sayı | Komut |
|---|---|---|
| Birim + duman (`test/`) | 23 | `.\run.ps1 -Check` |
| Arayüz, pytest-qt (`test/ui/`) | 17 | `.\run.ps1 -UiTest` |

Arayüz testleri dosya diyaloglarını ve soru kutularını taklit eder, yalnızca `tmp_path` altında örnek görsel
üretip dönüştürür; envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Kuyruk satırlarında klavyeyle gezinme yok (seçim fareyle; `Del` seçiliyi kaldırır).
- Yalnızca koyu tema.
- HEIC için `pillow-heif` gibi bir eklenti paketlenmiyor.
- Küçük resim önbelleği sınırsız (binlerce dosyada LRU'ya geçilebilir).
- Yol haritası: önizleme penceresi, dosya başına çıktı boyutu / kazanç özeti.
