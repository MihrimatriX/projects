# Metin Dönüştürücü

29 yerel metin aracı (Base64, URL, JWT, hash, JSON, Türkçe büyük/küçük harf, slug...) sunan, internetsiz çalışan Flutter masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

29 araç, 5 kategoride:

| Kategori | Araçlar |
|----------|---------|
| Encode / Decode (8) | Base64 encode/decode, URL encode/decode, HTML entities encode/decode, JWT decode (payload) ve (header) |
| Hash (2) | MD5, SHA-256 |
| Format (6) | JSON pretty/minify, Trim whitespace, Sort lines (A-Z), Tekrarlanan satırları sil, Word / char count |
| Generate (2) | UUID v4, Random string (16) |
| Convert (11) | camelCase, snake_case, kebab-case, Slug, Unix → ISO, UPPERCASE, lowercase, BÜYÜK HARF / küçük harf / Başlık Düzeni (Türkçe), Reverse text |

- Base64 decode URL-safe, dolgusuz ve satır sonlu girdiyi kabul eder; HTML entity adlı + sayısal; hash UTF-8 baytları üzerinden hesaplanır
- Türk alfabesine göre satır sıralama (CRLF korunur), kelime/karakter/satır/bayt sayımı (emoji ve birleşik harfler tek karakter), reverse grafem kümelerini bozmaz
- camelCase/snake_case/kebab-case (Türkçe harfler korunur, `parseHTTPResponse` gibi girdiler bölünür); Slug: "Çalışma Şekli" → `calisma-sekli`
- Türkçe büyük/küçük harf ve Başlık Düzeni (i ↔ İ, ı ↔ I doğru eşlenir); dilden bağımsız UPPERCASE/lowercase ayrıca var
- Çıktıyı girdi yap (`Ctrl+Shift+Enter`): dönüşümleri zincirle (ör. JSON minify → Base64)
- Yazdıkça canlı dönüşüm; araç arama (aksan gerekmez: "buyuk" → BÜYÜK HARF) ve daraltılabilir kategori grupları; son kullanılan araç açılışta hatırlanır
- Büyük metin (200 bin karakter üzeri) arka plandaki isolate'te dönüştürülür, arayüz donmaz; çıktı önizlemesi kısaltılır, kopyalama tam çıktıyı alır; 1 milyon karakter üzerinde uyarı bandı gösterilir
- JWT veya private key yapıştırılınca uyarı bandı
- Açık/koyu/sistem teması (varsayılan koyu); duyarlı yerleşim: geniş ekranda kenar çubuğu, orta genişlikte ikonlu kenar çubuğu, dar ekranda "Araçlar / Dönüştür" sekmeleri

## Hızlı başlangıç

```powershell
.\run.ps1             # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome      # cihazı elle seç (windows, chrome, edge veya flutter devices id'si)
.\run.ps1 -Check      # sadece flutter analyze + flutter test
.\publish.ps1         # Windows exe -> dist\hizli-metin-manipulasyon-ve-donusturucu-araclar\hizli_metin_manipulasyon_ve_donusturucu_araclar.exe
```

Windows exe üretmek (`.\publish.ps1`) ve Windows masaüstü hedefiyle çalıştırmak için Windows Geliştirici Modu açık olmalıdır (Flutter eklentileri symlink ister): `start ms-settings:developers`. Mod kapalıyken `run.ps1` Chrome/Edge'e düşer; `publish.ps1` net bir mesajla durur.

Manuel:

```powershell
flutter pub get
flutter run -d windows   # veya -d chrome
flutter test
```

Gereksinimler: Flutter SDK 3.x (Dart >= 3.2); Windows masaüstü için Visual Studio + "Desktop development with C++".

## Kullanım

Soldan bir araç seçin, **Girdi** alanına yazın/yapıştırın; sonuç **Çıktı** alanında canlı görünür. "Panoya Kopyala" çıktıyı kopyalar. Hata veren araçlar (ör. geçersiz Base64/JSON) Türkçe "Geçersiz ..." mesajı gösterir.

| Kısayol | İşlev |
|---------|-------|
| `Ctrl+Shift+C` | Çıktıyı kopyala |
| `Ctrl+L` | Girdiyi temizle |
| `Ctrl+F` | Araç aramasına odaklan |
| `Ctrl+Enter` | Dönüştür |
| `Ctrl+Shift+Enter` | Çıktıyı girdi yap |

## Veri ve gizlilik

- Tüm dönüşümler cihazda yapılır; metin hiçbir yere gönderilmez ve girdi/çıktı diske yazılmaz.
- Yalnızca iki tercih `SharedPreferences` ile saklanır: tema (`theme_mode`) ve son kullanılan araç (`last_tool_id`). Windows'ta kullanıcının AppData klasöründe, web'de tarayıcı `localStorage`'ındadır. Veri klasörünü değiştiren bir ortam değişkeni yoktur.
- Metin için ağ erişimi yoktur. Tek ağ erişimi `google_fonts` paketinin Inter yazı tipini çalışma anında indirmesidir (yazı tipi pakette gömülü değil; indirilemezse Flutter'ın yedek yazı tipi kullanılır).

## Mimari / analiz

Teknoloji (pubspec / pubspec.lock): Flutter 3.x (SDK `>=3.2.0 <4.0.0`), `flutter_riverpod` 2.6.1 (tema durumu), `go_router` 18.0.2 (`/` ve `/settings`), `shared_preferences` 2.5.5, `crypto` 3.0.7 (MD5/SHA-256), `google_fonts` 8.2.1. Sürüm: 1.0.0+1.

```
lib/main.dart, lib/app.dart                  ProviderScope, MaterialApp.router, tema
lib/core/settings/settings_provider.dart     tema modu (StateNotifier + SharedPreferences)
lib/core/theme/                              renk token'ları ve açık/koyu tema
lib/features/tools/data/tool_registry.dart   tüm araçlar ve dönüşüm fonksiyonları
lib/features/tools/presentation/             ana ekran (kenar çubuğu + girdi/çıktı)
lib/features/settings/presentation/          ayarlar (tema, gizlilik notu, sürüm)
```

Veri akışı: her araç (`TextTool`) saf bir `String -> String` fonksiyonudur ve `allTextTools` listesinde kayıtlıdır. Ekran, seçili aracın dönüşümünü girdi değiştikçe (150 ms debounce) çalıştırır; 200 bin karakter üstü girdi `compute` ile ayrı isolate'te işlenir, bu arada gelen yeni girdi eski sonucu geçersiz kılar.

Tasarım kararları:
- Hatalar istisna yerine "Geçersiz ..." metni olarak döner; `isTransformError` yalnızca hata üretebilen (`canFail`) araçlar için kontrol eder.
- Isolate'e gönderilebilmesi için dönüşümler üst düzey fonksiyondur; isolate başlatılamazsa aynı iş parçacığında çalışılır.
- Dart'ın dilden bağımsız `toUpperCase/toLowerCase` davranışı Türkçe için elle eşlenmiş i/İ/ı/I çiftleriyle düzeltilmiştir.

## Testler

`test/` altında 2 dosya, 34 test: `tool_registry_test.dart` (29: Türkçe harf, Unicode, Base64/HTML/satır araçları, kod biçimleri, 1 MB+ girdi, arama, hassas veri algılama) ve `widget_test.dart` (5). Çalıştırma: `.\run.ps1 -Check` (analiz + test) veya `flutter test`.

## Bilinen sınırlar

- Windows exe için Geliştirici Modu gerekir (yukarıya bakın); yoksa uygulama web (Chrome/Edge) ile çalıştırılabilir.
- Dil seçeneği yalnızca Türkçe'dir; arayüzdeki araç adları İngilizce/Türkçe karışıktır.
- Araçlar yalnızca metin → metin dönüşümü yapar; dosya girişi/çıkışı yoktur. Çıktı önizlemesi 200 bin karakterle sınırlıdır (kopyalama tam çıktıyı alır).
- Girdi alanı `expands: true` ile tüm paneli kapladığından, yazılan metin (web derlemesinde gözlendi) alanın üstünde değil dikey ortasında görünür; çalışmayı etkilemez.
