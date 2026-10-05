# Kodsuz Web Kazıyıcı

URL ve CSS seçici ile web sayfalarından kod yazmadan veri çıkaran PySide6 masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

*Ekran görüntüsü, yerel bir demo sayfadan çıkarılan örnek ürün verisini gösterir.*

## Özellikler

- Gömülü tarayıcı (Qt WebEngine): JS/SPA sayfaları render edip ayrıştırır; istenirse statik mod (urllib)
- "Element seç" ile sayfada tıklayarak CSS seçici üretme
- Üç mod: bağlantılar, metin, tablo (sütun başına alt seçici, `a@href` gibi öznitelik desteği)
- Hazır şablonlar (E-ticaret, Blog, Haber, Bağlantı listesi); "Seçiciyi test et" ile eşleşme sayısı
- Lazy-load için otomatik kaydırma, statik modda `rel="next"` sayfalama takibi (her sayfa ayrı ayrıştırılır)
- robots.txt gerçekten uygulanır (`urllib.robotparser`): engelli sayfa indirilmez/çıkarılmaz, `Crawl-delay` dikkate alınır
- Hız sınırı: aynı sunucuya ardışık istekler arasında en az ayarlanan gecikme (sayfalama ve ardışık çalıştırmalar dahil)
- CSV (UTF-8 / UTF-8 BOM / ISO-8859-9), JSON ve Excel (.xlsx) dışa aktarma (`=` ile başlayan hücreler Excel'de formül
  olarak çalışmaz), son 20 çalıştırma geçmişi
- Sonuç tablosunda arama, sayfalama (10 satır) ve seçili satırları kopyalama

## Hızlı başlangıç

```powershell
dist\kodsuz-web-kaziyici-scraper\KodsuzWebKaziyici.exe   # .\publish.ps1 ile üretilmiş sürüm
.\run.ps1          # .venv oluşturur, requirements.txt kurar, uygulamayı açar
.\run.ps1 -Check   # pytest testlerini çalıştırır
.\publish.ps1      # testler + PyInstaller (--onedir --windowed) -> dist\kodsuz-web-kaziyici-scraper\
```

`.\run.ps1 -Check` testleri sayfaları yerel `http.server`'dan sunarak çalıştırır, internete çıkılmaz. Exe klasörü
(`KodsuzWebKaziyici.exe` + `_internal`) birlikte taşınmalıdır. Manuel: `pip install -r requirements.txt` ve `python main.py`.
Gereksinim: Python 3.11+ (PySide6 + PySide6-Addons, beautifulsoup4, openpyxl).

## Kullanım

1. Soldaki **Temel** sekmesinde URL ve ana CSS seçiciyi girin ya da bir hazır şablon seçin; seçiciyi bilmiyorsanız
   **Sayfayı tarayıcıda aç** → **Tarayıcı** sekmesinde **Element seç** ile sayfada tıklayın.
2. **Sütunlar** sekmesinde tablo modu için alt seçicileri (ör. `.product .price`, `a@href`) tanımlayın;
   **Gelişmiş** sekmesinde motor (tarayıcı / statik), bekleme, zaman aşımı, azami satır, User-Agent,
   HTML temizleme, sayfalama ve robots.txt denetimini ayarlayın.
3. Çıkarma modunu seçip **Çalıştır**'a basın; sonuçlar **Sonuçlar** sekmesinde görünür, CSV / JSON / Excel düğmeleriyle
   kaydedin. Geçmiş penceresinden eski bir çalıştırmanın URL, seçici ve modu forma geri yüklenir (sütun eşlemeleri saklanmaz).

| Kısayol | İşlev |
| --- | --- |
| `Ctrl+Enter` / `F5` | Çalıştır |
| `Ctrl+E` | CSV olarak dışa aktar |
| `Ctrl+Shift+E` | JSON olarak dışa aktar |
| `Ctrl+Shift+X` | Excel (.xlsx) olarak dışa aktar |

## Veri ve gizlilik

- Ayarlar ve son 20 çalıştırmanın geçmişi (URL, seçici, mod, satır sayısı) `~/.kodsuz-web-kaziyici/settings.json`
  dosyasında tutulur (Windows'ta `%USERPROFILE%\.kodsuz-web-kaziyici`); yazma önce geçici dosyaya yapılıp değiştirildiği
  için yarıda kesilirse dosya bozulmaz. Ortam değişkeniyle konum seçeneği yoktur; testler `USERPROFILE`/`HOME`'u
  geçici klasöre yönlendirir. Ayarlardan geçmiş kaydı kapatılabilir.
- Çıkarılan veriler yalnızca siz dışa aktarana kadar bellekte durur; uygulama veritabanı tutmaz.
- Ağ erişimi yalnızca sizin girdiğiniz adrese ve o sunucunun `/robots.txt` dosyasına yapılır (statik modda en çok 1,5 MB
  sayfa, sayfalamada en çok 10 sayfa; robots.txt en çok 512 KB). Gömülü tarayıcı sayfayı kendi betikleriyle yükler.
  Telemetri ve üçüncü taraf servis yoktur.
- Yalnızca izin verilen sitelerde, `robots.txt` ve kullanım şartlarına uygun kullanın; CAPTCHA aşma desteklenmez.

## Mimari / analiz

Teknoloji: Python 3.11+ (`pyproject.toml`; geliştirme ortamı Python 3.13, PySide6 6.11), PySide6 >=6.7.0 (+ Addons /
Qt WebEngine), beautifulsoup4 >=4.12.0, openpyxl >=3.1.0; testler pytest >=8.0.0, exe için PyInstaller >=6.10.

```
main.py                 giriş noktası (QApplication, simge, MainWindow)
ui/main_window.py       form (Temel/Sütunlar/Gelişmiş), sonuç tablosu, ayarlar ve geçmiş pencereleri, kısayollar
ui/browser_panel.py     gömülü Qt WebEngine tarayıcı, element seçici betiği, sayfa hazır olunca HTML alma
ui/theme.py             koyu tema (QSS)
utils/scraper.py        indirme, robots.txt, hız sınırı, ayrıştırma (BeautifulSoup), CSV/JSON/XLSX dışa aktarma
utils/config.py         ayarlar ve geçmiş (JSON)
test/                   pytest testleri + HTML fikstürleri (liste-1/2, urunler)
scripts/                generate-assets.ps1 (simge üretimi); assets/ simgeler ve manifest
```

Veri akışı: form → `ScrapeWorker` (QThread) → tarayıcı modunda Qt WebEngine'in render ettiği DOM (`run_after_ready`:
bekleme + isteğe bağlı otomatik kaydırma) ya da statik modda `urllib` ile indirilen HTML → `scrape_from_html` /
`scrape_with_selector` → seçici ve moda göre `rows` + `columns` → tablo (10 satırlık sayfalama), dışa aktarma ve geçmiş.

Tasarım kararları:

- robots.txt `urllib.robotparser` ile gerçekten uygulanır: engelli sayfa hiç indirilmez; dosya yoksa (4xx) her şey serbest
  sayılır (RFC 9309), okunamazsa uyarı gösterilir. Kapatmak "Gelişmiş" sekmesinden bilinçli bir adımdır.
- Hız sınırı, ana makine (host) başına son istek zamanıyla uygulanır; ardışık çalıştırmalar arasında da geçerlidir.
- Sonuç güven etiketi ("robots.txt uyumlu" vb.) yalnızca bir çalıştırma sonrası gerçek denetim sonucunu yansıtır.
- Pencere kapanırken çalışan iş parçacığı beklenir (QThread yok edilirse çökme olmasın).

## Testler

- pytest: 19 test — `test/test_scraper.py` (16: değer çıkarma, tablo/bağlantı/metin modları, sayfalama ve döngü
  koruması, robots.txt kuralları ve `Crawl-delay`, Türkçe hata iletileri, CSV/JSON/XLSX gidiş-dönüş) ve
  `test/test_config_ui.py` (3: ayar/geçmiş kalıcılığı, bozuk yapılandırma, ana pencere duman testi ve dışa aktarma)
- Çalıştırma: `.\run.ps1 -Check` ya da `.venv\Scripts\python.exe -m pytest -q`. Testler `QT_QPA_PLATFORM=offscreen` ile
  çalışır, gerçek kullanıcı klasörüne dokunmaz, sayfaları yerel `http.server`'dan sunar.

## Bilinen sınırlar

- Giriş gerektiren, CAPTCHA'lı veya bot korumalı siteler için destek yoktur; oturum açma akışı sunulmaz.
- Statik modda JS ile oluşan içerik görünmez (tarayıcı motorunu kullanın); sayfalama takibi yalnızca statik modda
  `rel="next"` bağlantısıyla çalışır ve en çok 10 sayfa gezer.
- Tablo modunda dört sabit sütun eşlemesi vardır (ürün/başlık, fiyat/değer, stok/meta, bağlantı).
- Sonuçlar tabloda sayfalı gösterilir; azami satır sayısı ayardan sınırlanır (varsayılan 500).
- Windows için yazılmış ve denenmiştir; exe PyInstaller `--onedir` çıktısıdır (tek dosya değil, kurulum sihirbazı yok).
