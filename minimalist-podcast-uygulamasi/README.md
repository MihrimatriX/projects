# Minimalist Podcast

Koyu temalı, reklamsız RSS podcast dinleyici (Flutter); abonelikler, sıra ve dinleme konumu cihazda/tarayıcıda yerel SQLite'ta (Drift) tutulur.

![Ekran görüntüsü](docs/ekran.png)

> Ekran görüntüsü web derlemesidir; içindeki "Çay & Kod" `test/fixtures/feed_basic.xml` demo feed'inden gelir, gerçek abonelik yoktur.

## Özellikler

- RSS adresiyle podcast ekleme (eklemeden önce feed doğrulanır; geçersiz adres, HTML sayfası, bölümsüz feed, mükerrer abonelik ve çevrimdışı durum Türkçe hata verir), abonelikten çıkma, OPML içe/dışa aktarma
- RSS: charset belirtmeyen feed'ler UTF-8 okunur; RFC 822 tarihleri (EST/PDT, saniyesiz, gün adsız), Podlove chapter (kesirli saniye), media:content; ses dosyası olmayan öğeler atlanır; ağ istekleri 20 sn zaman aşımlı
- Bölüm listesi, filtreler (tümü / dinlenmedi / indirildi), bölümlerde Türkçe harf duyarsız arama, kaldığın yerden devam (bölüm değiştirirken konum hemen kaydedilir)
- Çevrimdışı: bölüm önbelleği gösterilir; yenileme hatası anlaşılır mesaj verir, "Yeniden dene" düğmesi
- Oynatıcı: hız 0.8×–2×, Smart Speed, 15 sn geri / 30 sn ileri, uyku zamanlayıcı (15 / 30 / 60 dk), chapter listesi
- Dinleme sırası (sürükle-bırak), bölüm bitince sıradakine geçer
- Offline indirme (yalnızca masaüstü/mobil; web'de yok), varsayılan olarak yalnızca Wi-Fi ile
- OPML klasör senkronu (yalnızca masaüstü/mobil): seçilen klasördeki `.opml` dosyası değişince abonelikler otomatik içe aktarılır
- Klavye: Boşluk = oynat/duraklat, ← / → = geri/ileri sar

## Hızlı başlangıç

Gereksinimler: Flutter SDK (Dart 3.2+), Chrome, Windows PowerShell 5.1+. İlk web kurulumunda internet gerekir (`sqlite3.wasm` GitHub'dan indirilir).

```powershell
.\run.ps1          # Chrome > Edge > Windows sırasıyla ilk uygun cihaz (just_audio Windows'ta çalmaz)
.\run.ps1 chrome   # cihazı elle seç
.\run.ps1 -Check   # sadece flutter analyze + flutter test
.\publish.ps1      # Windows exe: <repo>\dist\minimalist-podcast-uygulamasi\ altına tek .exe
```

- `run.ps1` gerekirse `flutter pub get` çalıştırır. Web hedefinde ayrıca `sqlite3.wasm` + `drift_worker.js` hazırlığını (`setup-web.ps1`) yapar ve yerel CORS proxy'yi (port 8766) başlatır.
- **Windows exe için Geliştirici Modu gerekir:** Flutter eklentileri sembolik bağlantı ister. Kapalıysa `start ms-settings:developers` ile açın, sonra `.\publish.ps1` çalıştırın (kapalıyken betik bunu önerip durur). Visual Studio "Desktop development with C++" iş yükü de gerekir. Çıktı: `dist\minimalist-podcast-uygulamasi\` içinde tek `.exe`.
- Web'de elle derleme: `flutter build web` (önce `.\setup-web.ps1`), çıktı `build\web`.

**Windows'ta ses:** just_audio 0.9.x'in Windows masaüstü eklentisi yok (`.flutter-plugins-dependencies` Windows listesinde just_audio bulunmuyor). Exe açılır; kütüphane, abonelik ve sıra çalışır ama ses çalmaz — oynatma denemesinde Türkçe uyarı gösterilir. Windows'ta ses için `just_audio_windows` ya da `just_audio_media_kit` eklenmeli (Geliştirici Modu açıkken derlenip doğrulanmalı). Ses için şimdilik `.\run.ps1 chrome` kullanın.

## Kullanım

- **Podcast ekle:** kenar çubuğundaki / listedeki "Podcast ekle" → RSS adresi. Adres doğrulanır, bölümler çekilir.
- **Bölüm:** oynat düğmesi çalmaya başlar; `⋮` menüsü "Dinle", "Sıraya ekle", (masaüstünde) "İndir" / "İndirmeyi sil".
- **Oynatıcı:** mini oynatıcıya dokununca tam ekran oynatıcı açılır (hız, ±sarma, uyku zamanlayıcı, chapter'lar, sıra).
- **Ayarlar:** Smart Speed, yalnızca Wi-Fi ile indirme, tüm bölümleri yenile, OPML içe/dışa aktarma (metin olarak; masaüstünde dosyadan/dosyaya ve klasör senkronu), ağ proxy adresi (yalnızca web).

| Kısayol | İşlem |
|---|---|
| Boşluk | Oynat / duraklat (parça yüklüyse) |
| ← | 15 sn geri |
| → | 30 sn ileri |

## Veri ve gizlilik

- **Masaüstü/mobil:** `getApplicationDocumentsDirectory()` altında `minimal_podcast.db` (SQLite; abonelikler, bölümler, dinleme konumları, sıra). İndirmeler aynı klasörde `downloads\<feedId>\` altında. Ayarlar (`shared_preferences`) platformun kendi deposundadır. Konumu değiştiren bir ortam değişkeni yoktur.
- **Web:** veritabanı tarayıcıda (IndexedDB, `minimal_podcast_db`), ayarlar `localStorage`'dadır; veriler tarayıcıdan çıkmaz. Offline indirme yoktur.
- **Ağ erişimi:** yalnızca eklediğiniz RSS adresleri ile bölüm ses/kapak görselleri çekilir; analitik, hesap veya reklam yoktur. Masaüstünde istekler doğrudan yapılır. Web'de CORS yüzünden RSS istekleri sırayla şu proxy'lerden geçer: yerel `localhost:8766` (run.ps1 başlatır), `corsproxy.io`, `api.allorigins.win` — son ikisi üçüncü taraf olduğundan feed adresleriniz onlara görünür; Ayarlar'dan kendi proxy adresinizi verebilirsiniz.
- İlk açılışta (kayıtlı abonelik yoksa) örnek olarak "NPR News Now" aboneliği eklenir; silebilirsiniz.

## Mimari / analiz

Teknoloji (pubspec.yaml, sürüm 0.3.0+1): Flutter (Dart ≥ 3.2), flutter_riverpod ^2.5.1, go_router ^18.0.2, drift ^2.20.0 (+ sqlite3_flutter_libs, web'de sqlite3.wasm + drift worker; drift_dev/build_runner ile kod üretimi), just_audio ^0.9.42, http ^1.2.2, xml ^6.5.0, file_picker ^8.1.2, connectivity_plus ^7.3.2, shared_preferences, path_provider, intl, url_launcher, flutter_markdown.

```
lib/main.dart            ProviderScope + MyApp
lib/app.dart             go_router: 4 sekme (kütüphane, sıra, indirilenler, ayarlar) + /player
lib/app_shell.dart       sekme iskeleti, mini oynatıcı, alt gezinme çubuğu
lib/core/database/       Drift şeması (Feeds, Episodes, PlaybackPositionsTable, PlayQueueTable; schemaVersion 3),
                         native/web bağlantısı, eski shared_preferences verisinin göçü
lib/core/player/         just_audio oynatıcı (Notifier), sıra, konum kaydı, Smart Speed, klavye kısayolları, mini oynatıcı
lib/core/network/        PodcastHttp: zaman aşımı, web'de CORS proxy zinciri
lib/core/settings/       AppSettings (Smart Speed, Wi-Fi'de indir, proxy)
lib/core/theme/          koyu tema ve yerleşim sabitleri
lib/features/feeds/      RSS ayrıştırıcı, OPML, bölüm/abonelik repository'leri, yenileme servisi, OPML klasör senkronu
lib/features/home/       kütüphane ekranı (≥1024 px: kenar çubuğu + bölüm paneli; dar: üstte yatay liste)
lib/features/podcast/    podcast ekleme diyaloğu, bölüm satırı
lib/features/player/     tam ekran oynatıcı
lib/features/queue/      sıra ekranı (ReorderableListView)
lib/features/downloads/  indirme servisi (native/web ayrı uygulama), indirilenler ekranı
lib/features/settings/   ayarlar ekranı
scripts/cors-proxy.ps1   run.ps1'in başlattığı yerel CORS proxy (HttpListener, port 8766)
setup-web.ps1            sqlite3.wasm (pubspec.lock'taki sqlite3 sürümüyle eşleşen) + drift_worker.js hazırlar
```

Veri akışı: RSS adresi → `PodcastHttp` (web'de proxy zinciri) → `rss_parser` → `Episodes` tablosu (Drift) → Riverpod provider'ları → arayüz. Oynatma: bölüm → `PodcastPlayerNotifier` (just_audio) → konumlar `PlaybackPositionsTable`'a yazılır, sıra `PlayQueueTable`'dadır.

Tasarım kararları:
- Platforma göre koşullu içe aktarma (`connection_native/web`, `download_service_native/web`, `opml_sync_service_native/web`) ile web ve masaüstü aynı kod tabanını paylaşır.
- Bölüm önbelleği veritabanında tutulur; ağ hatasında önbellek gösterilir.
- `setup-web.ps1` WASM sürümünü `pubspec.lock` ile eşler (uyuşmazlık `LinkError` verir); damga dosyasıyla gereksiz indirmeyi atlar.
- Koyu tema sabittir (`ThemeMode.dark`).

## Testler

`flutter test` veya `.\run.ps1 -Check` (analiz + test). Test dosyaları: `rss_parser_test` (10), `persistence_test` (8), `episode_filter_test` (3), `episode_progress_key_test` (1), `smart_speed_test` (1), `widget_test` (1) — toplam 24 test çağrısı. RSS/OPML testleri `test/fixtures` altındaki yerel dosyalarla çalışır, canlı internet gerekmez.

## Bilinen sınırlar

- Windows'ta ses çalmaz (yukarıya bakın); ses için web/Chrome kullanın.
- Offline indirme ve OPML klasör senkronu web'de yoktur.
- Web'de RSS için CORS proxy gerekir; yerel proxy yalnızca `run.ps1` ile başlar, genel proxy'ler kararsız olabilir.
- Windows exe'si Geliştirici Modu açık olmadan derlenemez; bu ortamda exe doğrulanmadı.
