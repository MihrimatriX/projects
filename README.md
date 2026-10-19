# DEV Projects

Windows için yazılmış 41 bağımsız masaüstü ve web uygulaması. Her klasör ayrı bir proje; uygulamalar verilerini bilgisayarda tutar.

Ekran görüntüleri ve özellik listeleri: https://mihrimatrix.github.io/projects/ (güncellemek için `.\site\publish.ps1`)

## Çalıştırma

```powershell
.\DevProjects.exe              # grafik başlatıcı (yoksa: .\proje-launcher\publish.ps1)
.\launcher.cmd                 # konsol menüsü
.\launcher.ps1 -Run regex      # isim parçasıyla doğrudan başlat
.\launcher.ps1 -Doctor         # .NET 10 / Flutter / Python / Node kurulu mu?
.\launcher.ps1 -Publish all    # tüm projeler için bağımsız exe üret (dist\<proje>\)
```

Başlatıcı eksik bir araç bulursa `winget` ile kurmayı önerir. Her projenin `run.ps1` dosyası tek başına da çalışır, testler için `.\run.ps1 -Check`.

Gereksinimler: .NET 10 SDK, Flutter 3.x, Python 3.11+, Node.js 22.12+. İsteğe bağlı olarak Rust (JSON formatlayıcının Tauri modu) ve ffmpeg (ekran kaydı, MP3 dökümü).

Notlar:
- Flutter projelerinin Windows exe'si için Windows Geliştirici Modu açık olmalı (`start ms-settings:developers`).
- `run.ps1` açılmıyorsa: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- Web Clipper eklentisi: `chrome://extensions` → Geliştirici modu → Paketlenmemiş yükle → `web-clipper-ve-okuma-listesi\extension`
- Sesli metin dökümü aracı konuşma modelini ilk kullanımda indirir (small ≈ 484 MB).
- Podcast uygulaması Windows masaüstünde ses çalamaz (eklenti yok), web sürümünde çalar.
- Uygulamalar verilerini `%LOCALAPPDATA%` / `%APPDATA%` altında tutar, exe klasörü taşınabilir.

## Portlar

Web ve Electron projelerinin sabit portları var, aynı anda çalışabilirler.

| Proje | Port |
|---|---|
| egitim-ve-ogrenme-platformu | 3101 |
| gorsel-not-ve-beyin-haritasi-araci | 3102 |
| json-formatlayici-ve-dogrulayici | 3103 |
| kisisellestirilebilir-haber-ve-icerik-akis-paneli | 3104 |
| regex-test-ve-ogrenme-araci | 3105 |
| takim-iletisim-ve-sohbet-araci | 3106 |
| web-clipper-ve-okuma-listesi | 3107 |
| dosya-ve-klasor-karsilastirici | 5171 |
| e-posta-istemcisi-ve-takip-araci | 5172 |
| kod-parcasi-snippet-yoneticisi | 5173 |
| yerel-webhook-test-araci | 5174 (arayüz), 8787 (webhook) |

## Projeler

### Verimlilik

- [Akıllı Liste](hizli-not-alma-ve-gorev-listesi): Görevleri, projeleri, etiketleri ve hızlı notları yerel SQLite veritabanında tutan; tekrar, alt görev ve otomatik dosya yedeği destekleyen Todoist tarzı görev listesi.
- [Alışkanlık Takipçisi](aliskanlik-takipcisi): Günlük ve haftalık alışkanlıkları seri sayacı, esnek seri ve 90 günlük ısı haritasıyla takip eden, verisini yalnızca cihazda tutan uygulama.
- [Ekran Zamanı](ekran-zamani-ve-uygulama-kullanim-takibi): Hangi uygulamada ne kadar vakit geçirdiğinizi ölçen, kategorilere ayıran ve yalnızca bu bilgisayarda saklayan WinUI 3 uygulaması.
- [Görsel Not ve Beyin Haritası](gorsel-not-ve-beyin-haritasi-araci): tldraw tuvali üzerinde pano oluşturup yerel SQLite'a otomatik kaydeden çevrimdışı not ve beyin haritası aracı.
- [Markdown Not Defteri](markdown-not-defteri): Yerel .md dosyalarını ve hızlı notları bölünmüş editör ile canlı önizlemede düzenleyen, otomatik kaydeden ve HTML/Markdown olarak dışa aktaran not defteri.
- [Odaklanma: Zaman Takip ve Pomodoro](zaman-takip-ve-pomodoro-araci): Proje bazlı süre kaydı, günlük rapor ve Pomodoro sayacı sunan Windows masaüstü uygulaması.
- [Otomasyon ve Makro Aracı](otomasyon-ve-makro-araci): Fare ve klavye adımlarını kaydedip düzenleyen ve tekrar oynatan Windows makro aracı.
- [Pano Geçmişi Yöneticisi](clipboard-gecmisi-yoneticisi): Kopyalanan metin, bağlantı, kod, görsel ve dosya yollarını yerel SQLite'ta saklayan, global kısayolla açılan sistem tepsisi pano geçmişi aracı.
- [QR Kod & Barkod](hizli-qr-kod-ve-barkod-olusturucu-okuyucu): URL, metin, Wi-Fi ve vCard için QR kod ile Code128/EAN-13 barkod üreten, görselden ve kameradan kod okuyan araç.
- [Takvim ve Zamanlayıcı](takvim-ve-zamanlayici): Türkçe, çevrimdışı takvim: ay/hafta/gün görünümü, tekrarlayan etkinlikler, doğal dil girişi, ICS/JSON aktarımı ve entegre Pomodoro zamanlayıcı.

### Dosya ve Sistem

- [Akıllı Dosya Arama](akilli-dosya-arama-motoru): Ctrl+Space ile açılan Spotlight tarzı yerel dosya arama paleti.
- [Disk Alanı Görselleştirici](disk-alan-gorsellestirici): Disk kullanımını sunburst ve treemap grafikleriyle gösterir; büyük dosyaları, temizlenebilir önbellekleri ve zaman içindeki büyümeyi bulup çöpe taşımanızı sağlar.
- [Dosya ve Klasör Karşılaştırıcı](dosya-ve-klasor-karsilastirici): İki dosyayı veya klasörü yan yana karşılaştıran, farkları birleştiren ve patch üreten yerel Electron uygulaması (Meld / WinMerge alternatifi).
- [Dosya Yeniden Adlandırıcı](dosya-yeniden-adlandirici): Kural zinciri ve canlı önizlemeyle toplu dosya yeniden adlandırma; çakışmaları engeller, hiçbir dosyanın üzerine yazmaz, kalıcı geri al / yinele sunar.
- [Hızlı Dosya Arama](hizli-dosya-arama-ve-acma-araci): Alt+F ile açılan, dosya adlarını yerel SQLite indeksinde yazdıkça arayıp Enter ile açan klavye odaklı Windows aracı (tepsi + tek örnek).
- [Komut Paleti](evrensel-uygulama-ve-dosya-baslatici): Alt+Space ile açılan Windows komut paleti: Başlat Menüsü uygulamalarını, dosya/klasör yollarını, PowerShell komutlarını ve web aramasını tek kutudan başlatır.
- [Sistem Yöneticisi Paketi](sistem-yoneticisi-paketi): Telemetrisiz yerel sistem monitörü: CPU, RAM, disk ve ağ izleme ile süreç, servis, başlangıç öğesi ve bağlantı yönetimi.
- [Tekrarlanan Dosya Bulucu](tekrarlanan-dosya-bulucu): Aynı içerikli dosyaları SHA-256 ile (isteğe bağlı benzer görselleri pHash ile) bulur ve kopyaları güvenle Geri Dönüşüm Kutusu'na taşır.

### Geliştirici Araçları

- [HookYerel: Yerel Webhook Test Aracı](yerel-webhook-test-araci): Webhook isteklerini internete açmadan 127.0.0.1 üzerinde yakalayan, mock yanıt veren ve Stripe/GitHub/Shopify imzalarını doğrulayan masaüstü aracı.
- [JSON Formatlayıcı ve Doğrulayıcı](json-formatlayici-ve-dogrulayici): JSON'u yerelde formatlayan, doğrulayan, JSONPath/jq-lite ile sorgulayan ve iki JSON'u satır satır karşılaştıran araç.
- [Kod Parçası Snippet Yöneticisi](kod-parcasi-snippet-yoneticisi): Kod parçalarını yerelde saklayan, Alt+Shift+S arama paletiyle her yerden kopyalanabilen snippet yöneticisi.
- [Kodsuz Web Kazıyıcı](kodsuz-web-kaziyici-scraper): URL ve CSS seçici ile kod yazmadan web verisi çıkaran PySide6 uygulaması; gömülü tarayıcı, robots.txt uyumu ve CSV/JSON/Excel dışa aktarma sunar.
- [Metin Dönüştürücü](hizli-metin-manipulasyon-ve-donusturucu-araclar): Base64, URL, JWT, hash, JSON, UUID ve Türkçe büyük/küçük harf dahil 29 metin aracı; tüm dönüşümler çevrimdışı ve cihazda yapılır.
- [Proje Launcher](proje-launcher): Monorepodaki tüm uygulamaları ekran görüntülü kartlarla listeleyen, arayıp filtreleyen ve tek tıkla açan WPF galeri (DevProjects.exe).
- [Regex Test ve Öğrenme Aracı](regex-test-ve-ogrenme-araci): Düzenli ifadeleri canlı eşleşme vurgusu, yakalama grupları ve replace önizlemesiyle test eden; adım adım debugger, ReDoS uyarısı ve aranabilir Türkçe cheatsheet sunan araç.

### Tasarım ve Görsel

- [Canlı Duvar Kağıdı Motoru](canli-duvar-kagidi-motoru): Windows masaüstüne görsel, video veya HTML/JS tabanlı canlı duvar kağıtları yerleştiren WinUI 3 uygulaması.
- [Ekran Renk Seçici](ekran-renk-secici): Global kısayolla ekrandaki herhangi bir pikselin rengini büyüteçle yakalayıp HEX/RGB/HSL/OKLCH olarak panoya kopyalayan tepsi uygulaması; WCAG kontrast, palet ve token dışa aktarma içerir.
- [Görsel Arama ve Toplu Dönüştürücü](gorsel-arama-ve-toplu-donusturucu): Görselleri kuyruğa toplayıp WebP, JPEG, PNG veya AVIF'e toplu dönüştürür, küçültür ve EXIF/GPS bilgisini temizler.
- [Renk Seçici ve Palet Üretici](renk-secici-ve-palet-uretici): Harmonik 5 renkli palet üretir, WCAG kontrastını gösterir; paleti CSS, SCSS, Tailwind veya JSON olarak dışa aktarır.

### İletişim ve Okuma

- [E-posta İstemcisi ve Takip Aracı](e-posta-istemcisi-ve-takip-araci): IMAP/SMTP hesaplarını yerel SQLite önbelleğiyle yöneten masaüstü e-posta istemcisi.
- [Haber Akış Paneli](kisisellestirilebilir-haber-ve-icerik-akis-paneli): RSS/Atom akışlarını yerel SQLite'ta toplayan üç sütunlu haber okuyucu.
- [Kayıtlı Okuma: Web Clipper ve Okuma Listesi](web-clipper-ve-okuma-listesi): Sayfaları kaydedip yan panelde okumanızı sağlayan Chrome (MV3) eklentisi; isteğe bağlı Next.js web arayüzü ve masaüstü sürümüyle RSS/Omnivore içe aktarma, vurgu ve notlar sunar.
- [Takım İletişim ve Sohbet Aracı](takim-iletisim-ve-sohbet-araci): Kendi sunucunuzda veya masaüstünde çalışan Slack benzeri anlık takım sohbeti.

### Medya ve Ekran

- [Gelişmiş Ekran Görüntüsü](gelismis-ekran-goruntusu-ve-not-alma-araci): Global kısayolla ekran yakalayan, işaretleme/pikselleştirme düzenleyicisi ve çevrimdışı OCR ile aranabilir geçmiş tutan WPF aracı.
- [Hızlı Ekran Kaydı ve GIF](hizli-ekran-kaydi-ve-gif-olusturucu): Ekranın seçili bölgesini kaydedip kırpan ve GIF ya da MP4 olarak dışa aktaran WPF uygulaması.
- [Minimalist Podcast](minimalist-podcast-uygulamasi): Koyu temalı, reklamsız RSS podcast dinleyici: abonelik, OPML içe/dışa aktarma, sıra, uyku zamanlayıcı ve offline indirme.
- [Yerel Sesli Metin Dökümü Aracı](yerel-sesli-metin-dokumu-araci): Ses dosyalarını faster-whisper ile tamamen bilgisayarınızda Türkçe metne çeviren araç; zaman damgalı transkript, dalga formu oynatıcı ve TXT/SRT/VTT dışa aktarma sunar.

### Güvenlik ve Gizlilik

- [Dijital Kasa](dosya-sifreleme-ve-dijital-kasa): Dosyaları parola korumalı yerel bir klasörde AES-256-GCM ve Argon2id ile şifreleyen, ekleme, kasaya taşıma, çıkarma ve otomatik kilit sunan WPF kasa.
- [Metadata Temizleyici](metadata-temizleyici): Fotoğraf ve PDF'lerdeki EXIF/GPS/XMP/IPTC izlerini yerelde, yedekli ve toplu olarak temizler.

### Yaşam ve Öğrenme

- [Öğrenim Pazarı](egitim-ve-ogrenme-platformu): Kurs kataloğu, ders ilerlemesi ve sunucuda puanlanan quiz içeren yerel eğitim platformu.
- [Yemek Planlayıcı](yemek-tarifi-yoneticisi-ve-menu-planlayici): Yerel tarif arşivi, haftalık 7×3 menü planı ve plandan otomatik birleşik alışveriş listesi; porsiyon ölçekleme ve kiler desteği.
