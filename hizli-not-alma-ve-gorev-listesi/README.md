# Akıllı Liste (Hızlı Not ve Görev)

Görevleri ve hızlı notları yerel SQLite veritabanında tutan, Todoist tarzı Flutter masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

*Ekran görüntüsü, bellek içi demo veriyle `flutter test` ortamında çizilmiştir (Windows Geliştirici Modu kapalı olduğundan exe derlenemedi); gerçek uygulamada yazı tipi Inter'dir.*

## Özellikler

- Görünümler: Bugün, Gelen Kutusu, Yaklaşan, Tümü, Takvim, Hızlı Notlar, proje ve etiket; kenar çubuğunda görev sayaçları
- Hızlı ekleme: `#etiket @bağlam Market al` yazımı otomatik etikete dönüşür
- Görev detayı: son tarih, not, öncelik (Normal/Düşük/Yüksek), alt görevler, proje seçimi, silme
- Günlük/haftalık/aylık tekrar (tamamlanınca kayıt kapanır, sonraki tarihle yeni görev açılır; ay sonu taşmaz: 31 Ocak → Şubat sonu)
- Projeler: renk seçimi, düzenleme/silme; etiketler görev sayısıyla listelenir
- Hızlı notlar: ekle, düzenle (çok satırlı), Türkçe harf duyarsız arama, silmeyi "Geri al"
- JSON dışa/içe aktarma (pano üzerinden); bozuk/alakasız JSON reddedilir, mevcut veri silinmez
- Dosya yedekleri: `Belgeler\Akilli Liste Yedekleri\` — açılışta günde bir otomatik yedek,
  içe aktarma ve "Tüm veriyi sil" öncesinde otomatik yedek, Ayarlar'dan elle yedek ve
  "Yedekten geri yükle" (son 20 yedek tutulur)
- Tüm veriyi silme (önce yedek alınır)
- Açık/koyu tema, tamamlanan görevleri göster/gizle; kısayollar: `n` yeni görev, `Esc` seçimi kapat

## Hızlı başlangıç

```powershell
.\run.ps1             # Windows masaüstü (Drift kodu yoksa üretir)
.\run.ps1 <cihaz-id>  # flutter devices çıktısındaki bir cihaz (ör. Android)
.\run.ps1 -Check      # sadece flutter analyze + flutter test
.\publish.ps1         # Windows exe -> dist\hizli-not-alma-ve-gorev-listesi\hizli_not_alma_ve_gorev_listesi.exe
```

Windows exe üretmek (`.\publish.ps1`, `flutter build windows`) ve Windows masaüstü hedefiyle çalıştırmak için Windows Geliştirici Modu açık olmalıdır (Flutter eklentileri symlink ister): `start ms-settings:developers` — kapalıysa betik bu önerisiyle durur.

Manuel:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # sadece app_database.g.dart yoksa
flutter run -d windows
flutter test
```

Gereksinimler: Flutter SDK 3.x (Dart >= 3.2); Windows masaüstü için Visual Studio C++ araçları. Veritabanı `drift/native` (dart:io) kullandığı için web (Chrome/Edge) hedefinde çalışmaz.

## Kullanım

Sol kenar çubuğundan görünüm, etiket veya proje seçilir; üstteki satıra yazıp Enter (veya "Ekle") ile görev eklenir. Göreve tıklayınca detay paneli açılır. "Hızlı Notlar" görünümü serbest metin notları tutar. Ayarlar'dan tema, yedekleme ve veri işlemleri yönetilir.

| Kısayol | İşlev |
|---------|-------|
| `n` | Hızlı ekleme satırına odaklan |
| `Esc` | Seçimi kapat |

## Veri ve gizlilik

- Tüm veri yerel SQLite dosyasındadır: Belgeler klasöründe `not_gorev.sqlite` (`getApplicationDocumentsDirectory`). Veri konumunu değiştiren bir ortam değişkeni yoktur.
- JSON yedekleri `Belgeler\Akilli Liste Yedekleri\akilli-liste-*.json` olarak yazılır (son 20 tutulur); dışa aktarma ve içe aktarma panoyu kullanır.
- Görev/not verisi için ağ erişimi, hesap veya telemetri yoktur. Tek ağ erişimi `google_fonts` paketinin Inter yazı tipini çalışma anında indirmesidir (yazı tipi pakette gömülü değil; indirilemezse Flutter'ın yedek yazı tipi kullanılır).
- Eski `SharedPreferences` verisi (`tasks_v1`, `quick_notes_v1`) ilk açılışta tek seferlik SQLite'a taşınır.

## Mimari / analiz

Teknoloji (pubspec / pubspec.lock): Flutter 3.x (SDK `>=3.2.0 <4.0.0`), `flutter_riverpod` 2.6.1, `drift` 2.35.1 + `sqlite3_flutter_libs` 0.5.42 (`drift_dev` 2.35.1 ve `build_runner` 2.16.1 ile kod üretimi), `path_provider` 2.1.6, `intl` 0.20.3 (tr_TR), `shared_preferences` 2.5.5 (yalnızca eski veri taşıma ve tercihler), `google_fonts` 8.0.0. Veritabanı şema sürümü 2 (v1 → v2 geçişi öncelik, tekrar, etiket tablolarını ekler). Uygulama sürümü: 1.1.0+2.

```
lib/main.dart, lib/app.dart   açılış (eski veri taşıma, günlük yedek), MaterialApp, tema
lib/core/database/            Drift tabloları (Projects, Tasks, Subtasks, Tags, TaskTags, QuickNotes), bağlantı ve provider
lib/core/                     task_filters, task_groups, recurrence, task_input_parser (hızlı ekleme),
                              export_service / import_service / backup_service / data_reset_service, text_search, theme/
lib/features/tasks/           görev modeli, depo, provider'lar, ana liste, takvim görünümü, kenar çubuğu, hızlı ekleme çubuğu, detay paneli
lib/features/notes/           hızlı notlar
lib/features/projects/, tags/ proje ve etiket modeli/depo/provider
lib/features/settings/        ayarlar (tema, yedekleme, içe/dışa aktarma, silme)
lib/features/shell/           AppShell (kenar çubuğu / alt gezinme)
design/                       HTML tasarım prototipleri
tools/sync-icons.ps1          ikon eşitleme
.github/workflows/ci.yml      CI (analyze + test)
```

Veri akışı: tek bir `AppDatabase` (Drift) `databaseProvider` ile paylaşılır; repository'ler tablolara erişir, Riverpod provider'ları durumu tutar ve ekranlar dinler. Görünüm filtreleri (`TaskView`) saf fonksiyonlardır (`task_filters`, `task_groups`), bu yüzden doğrudan birim testlenebilir. İçe aktarma tek transaction'da çalışır; hatalı yedek mevcut veriyi değiştirmez.

Tasarım kararları:
- Yerel-öncelikli: bulut hesabı bilinçli olarak yoktur; taşınabilirlik JSON ve dosya yedekleriyle sağlanır.
- Yıkıcı işlemlerden (içe aktarma, tüm veriyi sil) önce otomatik yedek alınır; yedek alınamazsa silme yapılmaz.
- Yedek biçimi veri silinmeden önce doğrulanır (sürüm ve liste alanları).
- Testler `NativeDatabase.memory()` ile gerçek SQLite'ı bellek içinde kullanır.

## Testler

`test/` altında 6 dosya, 24 test: `data_persistence_test.dart` (14: şema geçişi, kalıcılık, yedek, içe/dışa aktarma, silme), `recurrence_test.dart` (3), `task_filters_test.dart` (2), `task_input_parser_test.dart` (2), `widget_test.dart` (2), `task_groups_test.dart` (1). Çalıştırma: `.\run.ps1 -Check` (analiz + test) veya `flutter test`.

## Bilinen sınırlar

- Yalnızca Windows masaüstü için hedeflenmiştir; web'de çalışmaz (`drift/native`). Windows exe için Geliştirici Modu gerekir (yukarıya bakın).
- Görev sürükle-bırak sıralaması arayüzde yoktur (veri katmanında `reorder` var; eski tasarım belgeleri sürükle-bırak'tan söz eder).
- Dışa/içe aktarma panoya dayanır; JSON dosya seçici yoktur (dosya yedekleri ayrıca vardır).
- Bulut senkronizasyonu, çok kullanıcı ve bildirim/hatırlatıcı yoktur.
