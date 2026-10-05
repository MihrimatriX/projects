# Alışkanlık Takipçisi

Günlük/haftalık alışkanlıkları seri (streak) ve ısı haritasıyla takip eden, tamamen yerel çalışan Flutter uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Tek dokunuşla günlük check-in, günlük/haftalık seri sayacı ("Aktif seri" kartı)
- Esnek seri: haftada N/7 gün yeterli (3–7 arası hedef)
- Son 90 günün ısı haritası, tamamlanma oranı ve gün detayı
- Isı haritasında geçmiş bir günü seçip unutulan check-in'i sonradan işaretleme/kaldırma
- Zincir alışkanlıklar: biri bitince sıradakini hatırlatır (A → B → C, döngüsel zincire karşı korumalı)
- Alışkanlık başına ad, emoji ikon, renk, sıklık (günlük/haftalık), esnek seri ve tetikleyici alışkanlık seçimi
- Günlük hatırlatıcı ve Pazar haftalık rapor bildirimi (Android/iOS/macOS), Android ana ekran widget'ı; Windows/web'de rapor panoya kopyalanabilir
- Açık/koyu/sistem/AMOLED tema
- JSON/CSV dışa aktarma (panoya) ve JSON yedeğini panodan geri yükleme (doğrulamalı; hatalı yedek mevcut veriye dokunmaz)
- Seri hesabı yerel takvim günlerine dayanır: yaz saati geçişi, ay/yıl sınırı ve saat dilimi değişikliği seriyi bozmaz; uygulama gece yarısını açık geçirirse durum kendiliğinden yenilenir
- Bozuk kayıt verisi açılışta yedeklenir (`habits_v2_bozuk_*`), sessizce ezilmez

## Hızlı başlangıç

```powershell
.\run.ps1             # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome      # cihazı elle seç (windows, chrome, edge veya flutter devices id'si)
.\run.ps1 -Check      # sadece flutter analyze + flutter test
.\publish.ps1         # Windows exe -> dist\aliskanlik-takipcisi\aliskanlik_takipcisi.exe
```

Windows exe üretmek (`.\publish.ps1`) ve Windows masaüstü hedefiyle çalıştırmak için Windows Geliştirici Modu açık olmalıdır (Flutter eklentileri symlink ister): `start ms-settings:developers`. Mod kapalıyken `run.ps1` otomatik olarak Chrome/Edge'e düşer; `publish.ps1` ise net bir mesajla durur.

Manuel:

```powershell
flutter pub get
flutter run -d windows   # veya -d chrome
flutter test
```

Gereksinimler: Flutter SDK 3.x (Dart >= 3.2); Windows masaüstü için Visual Studio "Desktop development with C++"; Android için Android SDK.

## Kullanım

| Ekran | Ne yapılır |
|-------|-----------|
| Bugün | Karta dokunarak check-in; `+` ile yeni alışkanlık; karta uzun basınca düzenle/sil menüsü |
| Isı haritası | Son 90 gün; güne dokunup o günün alışkanlıklarını işaretle/kaldır; alışkanlık başına aktif seri |
| Zincir | Tetikleyici ilişkisi tanımlı alışkanlıkların sıralı görünümü |
| Ayarlar | Tema, hatırlatıcılar, raporu paylaş/kopyala, JSON/CSV dışa aktar, JSON içe aktar (panodan) |

Uygulamada klavye kısayolu tanımlı değildir.

## Veri ve gizlilik

- Tüm veri yalnızca cihazda `SharedPreferences` içinde tutulur: alışkanlıklar `habits_v2` anahtarında JSON olarak, tema `theme_mode`, hatırlatıcı ayarları `reminder_*` / `weekly_report_*` anahtarlarında. Windows'ta kullanıcının AppData klasöründe, web'de tarayıcı `localStorage`'ında, Android'de uygulama özel deposundadır.
- Veri klasörünü değiştiren bir ortam değişkeni yoktur.
- Uygulama kendi verisi için ağ isteği yapmaz, hesap/telemetri yoktur. Tek ağ erişimi `google_fonts` paketinin Inter yazı tipini çalışma anında indirmesidir (yazı tipi pakette gömülü değil; indirilemezse Flutter'ın yedek yazı tipi kullanılır).
- Dışa aktarma/yedekleme panoya yapılır; dosya oluşturulmaz. Rapor paylaşımı `share_plus` ile sistemin paylaşım arayüzünü kullanır, desteklenmeyen platformlarda panoya düşer.

## Mimari / analiz

Teknoloji (pubspec / pubspec.lock): Flutter 3.47 (SDK `>=3.2.0 <4.0.0`), `flutter_riverpod` 2.6.1 (durum yönetimi), `go_router` 18.0.2 (alt gezinme için `ShellRoute`), `shared_preferences` 2.5.5, `intl` 0.20.3 (tr_TR), `flutter_local_notifications` 18.0.1 + `timezone` 0.10.1, `share_plus` 13.3.1, `home_widget` 0.7.0, `google_fonts` 8.0.0; geliştirme: `flutter_lints`, `flutter_launcher_icons`. Sürüm: 0.3.0+2.

```
lib/main.dart            açılış: bootstrap (tr_TR tarih verisi), bildirim ve widget servisleri, ProviderScope
lib/app.dart             MaterialApp.router, yönlendirme (/, /stats, /chain, /settings), tema seçimi
lib/core/                date_utils (yerel gün anahtarları), streak_logic (seri hesabı), weekly_report,
                         notification_service, home_widget_service, theme/, widgets/
lib/features/habits/     model (Habit), depo (HabitsRepository), provider (HabitsNotifier), ekleme/düzenleme formu
lib/features/home/       Bugün ekranı, alışkanlık ve seri kartları
lib/features/stats/      ısı haritası ekranı ve ızgara bileşeni
lib/features/chain/      zincir grupları ve ekranı
lib/features/settings/   ayarlar ekranı
lib/features/shell/      alt gezinme çubuğu ve ortak FAB
android/                 HabitWidgetProvider.kt (ana ekran widget'ı)
```

Veri akışı: `HabitsRepository` kayıtlı JSON'u okur, `doneToday` ve seriyi `completionDates` listesinden (yerel `yyyy-MM-dd` anahtarları) yeniden hesaplayıp normalleştirir; `HabitsNotifier` (AsyncNotifier) durumu tutar, her değişiklikte kaydeder ve Android widget'ını eşitler; ekranlar `ref.watch` ile dinler. Dakikalık bir zamanlayıcı gün değişimini yakalayıp durumu yeniden hesaplatır.

Tasarım kararları:
- Seri hiçbir zaman sayaç olarak artırılmaz; her seferinde tarih listesinden türetilir (saat dilimi/yaz saati/gece yarısı hataları kendiliğinden düzelir).
- Okuma sırasında bozuk kayıt tespit edilirse ham veri `habits_v2_bozuk_<zaman>` anahtarına yedeklenir; içe aktarma ise katı doğrulama yapar ve hata durumunda mevcut veriyi korur.
- Bildirimler ve ana ekran widget'ı yalnızca desteklenen platformlarda başlatılır (`kIsWeb`/`Platform` korumaları).

## Testler

`test/` altında 3 dosya, 45 test: `streak_logic_test.dart` (27, seri/esnek seri/haftalık hesap), `habits_persistence_test.dart` (15, kayıt, geri yükleme, bozuk veri), `widget_test.dart` (3). Çalıştırma: `.\run.ps1 -Check` (analiz + test) veya `flutter test`.

## Bilinen sınırlar

- Windows masaüstünde ve web'de zamanlanmış bildirim ve ana ekran widget'ı yoktur (Android/iOS/macOS bildirimleri; widget yalnızca Android).
- Yedekleme panoya/panodan çalışır; dosya seçici ile içe/dışa aktarma yoktur. İçe aktarma mevcut alışkanlıkların yerine geçer.
- Cihazlar arası eşitleme yoktur.
- Isı haritası son 90 günü gösterir.
- Windows exe için Geliştirici Modu gerekir (yukarıya bakın); yoksa uygulama web (Chrome/Edge) ile çalıştırılabilir.
