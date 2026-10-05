# Yemek Tarifi Yöneticisi ve Menü Planlayıcı

Kişisel tarif arşivi, haftalık menü planı ve plandan otomatik alışveriş listesi (Flutter). Veriler yalnızca cihazda (SharedPreferences) tutulur.

![Ekran görüntüsü](docs/ekran.png)

> Ekran görüntüsü web derlemesidir; plandaki tarifler ilk açılışta eklenen örnek tariflerdir.

## Özellikler

- Tarif ekleme/düzenleme, arama, etiket ve süre filtresi (Tümü / <30 / <60 / >60 dk)
- Porsiyona göre malzeme ölçekleme (ör. 4 kişilik tarifi 2 kişiye indirme); `1 1/2`, `1½`, `½`, `2-3`, `yarım` gibi miktarlar anlaşılır, sonuç okunur birimde yazılır (`1,5 kg`, `0,25 çk`); paylaşılan tarif ölçeklenmiş malzemeyle gider
- Haftalık 7×3 öğün planı (kahvaltı / öğle / akşam), öğün başına porsiyon çarpanı (meal prep)
- Plandan birleşik alışveriş listesi; Türkçe birimler (g/kg, ml/l, adet, yk, sb, çk); kalan kalemleri panoya kopyalama
- Kiler: stoktaki malzemeleri alışveriş listesinde işaretleme/gizleme
- JSON ve Markdown tarif içe aktarma, tarifleri JSON olarak paylaşma; bozuk kayıt ekranı kilitlemez, ham veri `<anahtar>_bozuk_yedek` olarak saklanır
- Açık / koyu / sistem teması; dar pencerede alt gezinme çubuğu

## Hızlı başlangıç

Gereksinimler: Flutter SDK (Dart 3.2+); Windows masaüstü için Visual Studio C++ araçları ve Geliştirici Modu; web için Chrome veya Edge.

```powershell
.\run.ps1             # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome      # cihazı elle seç (Android için flutter devices id'si, ör. emulator-5554)
.\run.ps1 -Check      # sadece flutter analyze + flutter test
.\publish.ps1         # Windows exe: <repo>\dist\yemek-tarifi-yoneticisi-ve-menu-planlayici\ altına
```

Elle: `flutter pub get` ardından `flutter run -d windows` (veya `chrome`). Test: `flutter test`.

**Windows exe için Geliştirici Modu gerekir** (Flutter eklentileri sembolik bağlantı ister): `start ms-settings:developers` ile açın, ardından `.\publish.ps1` çalıştırın; kapalıyken betik Türkçe hata ile durur. Geliştirici Modu kapalıysa web hedefi (`.\run.ps1 chrome`) kullanılabilir; web'de Chrome → "Uygulamayı yükle" ile PWA olarak da kurulabilir.

## Kullanım

- **Tarifler:** "Yeni tarif" ile ekleyin; tarif sayfasında porsiyon sayısını değiştirerek malzemeleri ölçekleyin, "Plana ekle", "Paylaş", "Düzenle" ve silme düğmeleri vardır.
- **Plan:** boş bir öğün hücresine dokunup tarif atayın; meal prep için porsiyon çarpanı seçin (hücrede "2×"). Üstteki oklarla haftalar arasında gezin, "Bu hafta" bugüne döner.
- **Alışveriş:** planlayıcıda seçili haftanın planından birleşik liste; "Stoktakileri gizle" ile kilerdeki kalemler çıkarılır, kalanlar panoya kopyalanır.
- **Kiler:** evdeki malzemeleri ekleyin (hızlı ekleme önerileri var). Kiler yan menüde yoktur; ana sayfadan (kenar çubuğundaki logoya tıklayın) veya Alışveriş ekranındaki "Kiler" bağlantısından açılır.
- **Ayarlar:** JSON paylaş, JSON / Markdown içe aktar (metin yapıştırarak), tema, tüm veriyi sil.

Uygulamada klavye kısayolu tanımlı değildir.

## Veri ve gizlilik

- Tüm veri `shared_preferences` içindedir: `recipes_v1`, `week_plans_v1`, `pantry_v1`, `shopping_checked_v1`, `theme_mode_v1`, `seed_done_v1` (örnek tariflerin bir kez eklendiği bayrak). Windows'ta kullanıcı uygulama verisi klasöründeki `shared_preferences.json`, web'de tarayıcı `localStorage`. Konumu değiştiren bir ortam değişkeni yoktur.
- Ağ erişimi yoktur (HTTP istemcisi bağımlılığı yok); hesap, bulut veya analitik yoktur. Paylaşma `share_plus` ile sistemin paylaşım akışını kullanır.
- Ayarlar > "Tüm veriyi sil" tarifleri, planları, kileri ve alışveriş işaretlerini siler (geri alınamaz).
- Bilinçli kapsam dışı (AGENTS.md): besin değeri API'si, Paprika içe aktarma, bulut senkronu.

## Mimari / analiz

Teknoloji (pubspec.yaml, sürüm 1.2.0+3): Flutter (Dart ≥ 3.2), flutter_riverpod ^2.5.1, go_router ^18.0.2, intl ^0.20.3 (tr_TR), shared_preferences ^2.2.3, share_plus ^13.3.1.

```
lib/main.dart, app.dart           tr_TR biçimleri, ProviderScope; go_router ShellRoute:
                                  /, /recipes, /recipes/:id, /planner, /shopping, /pantry, /settings
lib/core/shopping_merge.dart      malzeme satırı ayrıştırma, birim normalleştirme, birleştirme, ölçekleme, okunur miktar
lib/core/import/recipe_import.dart   JSON ve Markdown tarif ayrıştırma
lib/core/safe_json.dart           bozuk kaydı yedekleyip null dönen güvenli JSON okuma
lib/core/seed/, data_reset.dart, week_utils.dart, theme/, widgets/   örnek tarifler, veri silme, hafta yardımcıları, tema, ortak bileşenler
lib/features/recipes/             Recipe modeli, repository, provider, liste / detay / form
lib/features/planner/             WeekPlan + MealSlot (7×3, porsiyon çarpanı), repository, provider, ekran
lib/features/shopping/            plandan birleşik liste, işaretler, repository
lib/features/pantry/              kiler (stok) verisi ve ekranı
lib/features/settings/            içe/dışa aktarma, tema, veri silme
lib/features/shell/               geniş ekranda kenar çubuğu (≥768 px), dar ekranda alt gezinme
test/                             ayrıştırma, ölçekleme, alışveriş listesi, kalıcılık ve içe aktarma testleri
```

Veri akışı: tarifler `RecipesRepository` (JSON, `recipes_v1`) → Riverpod provider; plan hafta anahtarıyla (`yyyy-MM-dd`, Pazartesi) `week_plans_v1` içinde saklanır; alışveriş listesi, seçili haftadaki planlı tariflerin malzeme satırlarını çarpanla ölçekleyip `mergeIngredientLines` ile aynı birimde birleştirerek üretilir (kilerdekiler isteğe bağlı gizlenir).

Tasarım kararları: tüm veri tek `shared_preferences` deposundadır (sunucu yok); hafta Pazartesi başlar; birimler Türkçe kısaltmalarla normalleştirilir (yk, sb, çk…); okunamayan kayıt `<anahtar>_bozuk_yedek` anahtarına kopyalanır, ekran açılmaya devam eder.

## Testler

`flutter test` veya `.\run.ps1 -Check` (analiz + test): `units_and_persistence_test` (14), `shopping_merge_test` (3), `recipe_import_test` (2), `scale_ingredients_test` (2), `widget_test` (1) — toplam 22 test çağrısı.

## Bilinen sınırlar

- Yedekleme yalnızca tarifleri kapsar (JSON paylaş); plan, kiler ve alışveriş işaretleri dışa aktarılmaz.
- İçe aktarma dosya seçmek yerine metin yapıştırarak yapılır.
- Tarif fotoğrafı alanı yoktur.
- Windows exe'si Geliştirici Modu açık olmadan derlenemez; bu ortamda exe doğrulanmadı.
