# QR Kod & Barkod

Çevrimdışı çalışan QR kod / barkod oluşturucu ve okuyucu; veriler cihazdan çıkmaz.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- QR oluşturma: URL, metin, Wi-Fi, vCard → PNG (4 modül sessiz bölgeli, tam piksel hizalı) veya SVG; hata düzeltme seviyesi L/M/Q/H, çıktı boyutu 512/1024 px, geçerli içerik yoksa uyarı
- Barkod: Code128 (ASCII) ve EAN-13 (kontrol basamağı otomatik)
- Toplu üretim: CSV/TXT (ilk sütun, en fazla 100 satır) → ZIP (QR PNG, QR SVG, Code128 SVG veya EAN-13 SVG); "Örnek CSV kopyala" ile örnek biçim alınır
- Okuma: kamera (Android/iOS/macOS); görsel dosyasından QR / Code128 / EAN-13 okuma **tüm platformlarda**
  (Windows ve web dahil; saf Dart çözücü, dikey/ters barkod ve ters renkli QR desteklenir); pano
- Okunan URL'yi açmadan önce "Harici bağlantı" onayı istenir
- Masaüstünde PNG/SVG/ZIP/JSON dışa aktarma "Farklı kaydet" penceresiyle dosyaya yazılır (mobil/web: paylaşım)
- Okunan Wi-Fi / vCard kodu "QR oluştur" ile forma alanlarıyla birlikte yüklenir
- Geçmiş: oluşturma ve okuma geçmişi (her biri en fazla 50 kayıt), JSON dışa/içe aktarma, Wi-Fi şifresi maskeleme
- Tema: açık / koyu / sistem (varsayılan koyu)

## Hızlı başlangıç

```powershell
.\run.ps1            # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome     # cihazı elle seç (windows, chrome, edge veya flutter devices id'si)
.\run.ps1 -Check     # sadece flutter analyze + flutter test
.\build.ps1 -windows # analiz + test + release derleme (veya -android)
.\publish.ps1        # Windows exe -> dist\hizli-qr-kod-ve-barkod-olusturucu-okuyucu\hizli_qr_kod_ve_barkod_olusturucu_okuyucu.exe
```

Windows exe üretmek (`.\publish.ps1`) ve Windows masaüstü hedefiyle çalıştırmak için Windows Geliştirici Modu açık olmalıdır (Flutter eklentileri symlink ister): `start ms-settings:developers`. Mod kapalıyken `run.ps1` Chrome/Edge'e düşer; `publish.ps1` net bir mesajla durur.

Elle: `flutter pub get` → `flutter run -d chrome` (veya `windows`, `android`).

Gereksinimler: Flutter SDK (Dart ≥ 3.2); Windows masaüstü için Visual Studio "Desktop development with C++". Web ve Windows'ta canlı kamera yoktur; görsel dosyasından okuma ve pano yapıştırma çalışır.

## Kullanım

Alt çubukta iki sekme vardır: **Oluştur** (QR / Barkod / Toplu alt sekmeleri) ve **Oku**. Sağ üstteki dişli Ayarlar'ı açar; Yardım ekranına Ayarlar > Hakkında bölümünden ulaşılır.

| Kısayol (Oku sekmesi) | İşlev |
|-----------------------|-------|
| `Ctrl+O` | Görsel dosyası aç ve içindeki kodu oku |
| `Ctrl+V` | Panodan yapıştır (görsel veya metin) |

Okunan sonuç için "Tarayıcıda aç", "Kopyala" ve "QR oluştur" eylemleri sunulur.

## Veri ve gizlilik

- Üretim ve okuma tamamen cihazda yapılır; veri sunucuya gönderilmez, hesap/telemetri yoktur; bağımlılıklar arasında yazı tipi veya başka içerik indiren paket yoktur.
- Ağ erişimi yalnızca kullanıcı okunan bir bağlantıda "Aç"ı onaylarsa, sistem tarayıcısı üzerinden olur (`url_launcher`, harici uygulama).
- Geçmiş ve ayarlar `SharedPreferences` içinde saklanır: `qr_history_v1`, `scan_history_v1` (JSON metinler), `mask_wifi_passwords_v1` (varsayılan açık), `theme_mode_v1`. Windows'ta kullanıcının AppData klasöründe, web'de tarayıcı `localStorage`'ındadır. Veri klasörünü değiştiren bir ortam değişkeni yoktur.
- Dosyalar (PNG/SVG/ZIP/JSON) yalnızca kullanıcının seçtiği konuma yazılır (masaüstü) veya paylaşım arayüzüyle verilir.

## Mimari / analiz

Teknoloji (pubspec / pubspec.lock): Flutter 3.x (SDK `>=3.2.0 <4.0.0`), `flutter_riverpod` 2.6.1, `go_router` 18.0.2 (`StatefulShellRoute` ile alt gezinme), `shared_preferences` 2.5.5, `qr` 3.0.2 + `qr_flutter` 4.1.0 (QR çizimi/üretimi), `barcode` 2.2.9 + `barcode_widget` 2.0.4 (Code128/EAN-13), `zxing2` 0.2.4 (saf Dart çözücü), `mobile_scanner` 6.0.11 (kamera), `image_picker` 1.2.3, `file_picker` 8.3.7, `archive` 3.6.1 (ZIP), `share_plus` 12.0.2, `url_launcher` 6.3.3. Sürüm: 1.3.0+4.

```
lib/main.dart, lib/app.dart   ProviderScope, go_router (/, /scan, /qr, /settings, /help), tema
lib/core/                     qr_presets (URL/metin/Wi-Fi/vCard), qr_export, qr_svg_export, barcode_utils,
                              batch_export + barcode_batch_export (ZIP), image_code_reader (görselden okuma),
                              history_export/import/display, contrast_utils, file_output, url_utils,
                              theme/, widgets/ (panel, chip, alt sekmeler)
lib/features/qr/              oluşturma ekranı: QR / Barkod / Toplu panelleri, geçmiş deposu ve provider
lib/features/scan/            okuma ekranı (kamera, dosya, pano), geçmiş deposu ve provider
lib/features/settings/        tema, Wi-Fi maskeleme, geçmiş yönetimi, hakkında
lib/features/help/            yardım ekranı
lib/features/shell/           alt gezinme (Oluştur / Oku)
```

Veri akışı: kullanıcı girdisi (`qr_presets`) tek bir içerik metnine dönüştürülür; QR `qr_flutter` ile ekranda çizilir, aynı içerikten PNG/SVG dışa aktarma üretilir. Okuma tarafında kamera `mobile_scanner` ile, görsel/pano ise `ImageCodeReader` ile çözülür (görsel `dart:ui` ile pikselleştirilir, 1600 px'e küçültülür, QR için zxing2, Code128/EAN-13 için satır tarayıcı kullanılır). Sonuçlar geçmiş deposuna JSON metin olarak yazılır.

Tasarım kararları:
- Okuma için kamera eklentisi olmayan platformlarda (Windows, web) da çalışsın diye çözücü saf Dart'tır.
- Router bir kez kurulur; tema değişince gezinme durumu sıfırlanmaz.
- Wi-Fi şifreleri geçmişte varsayılan olarak maskelenir.

## Testler

`test/` altında 10 dosya, 34 test: görselden okuma (11), QR ön ayarları (5), tarama ekranı (5), barkod yardımcıları (3), toplu dışa aktarma, kontrast, geçmiş gösterimi/içe aktarma (2'şer), SVG dışa aktarma ve widget testi (1'er). Çalıştırma: `.\run.ps1 -Check` (analiz + test) veya `flutter test`.

## Bilinen sınırlar

- Windows exe için Geliştirici Modu gerekir (yukarıya bakın); yoksa uygulama web (Chrome/Edge) ile çalıştırılabilir.
- Canlı kamera yalnızca Android/iOS/macOS'ta; Windows ve web'de görsel dosyası veya pano kullanılır.
- Görselden okuma yalnızca QR, Code128 ve EAN-13'ü destekler (uygulamanın ürettiği türler); büyük fotoğraflar 1600 px'e küçültülür.
- Toplu üretim en fazla 100 satır işler; geçmişler 50 kayıtla sınırlıdır.
