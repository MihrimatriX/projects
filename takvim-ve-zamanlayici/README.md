# Takvim ve Zamanlayıcı

Pomodoro sayaçlı, çevrimdışı çalışan Türkçe takvim uygulaması (Flutter). Hesap yok; veriler cihazda (SharedPreferences) kalır.

![Ekran görüntüsü](docs/ekran.png)

> Ekran görüntüsü web derlemesidir; etkinlikler uydurma demo verisidir.

## Özellikler

- Ay / hafta / gün görünümü, mini takvim ve arama
- Günlük, haftalık, aylık tekrarlayan etkinlikler; isteğe bağlı tekrar bitiş tarihi; tek/çok günlü tüm gün etkinlikleri (yaz saati geçişinde saat kaymaz)
- Türkçe doğal dil girişi: "Yarın 15:00 toplantı", "Cuma 10:30 doktor"
- Pomodoro (odak / kısa / uzun mola), isteğe bağlı takvime otomatik odak bloğu
- Hatırlatıcılar: Android/iOS/macOS'ta sistem bildirimi; Windows ve web'de (bildirim eklentisi desteklemez) uygulama açıkken uygulama içi uyarı + ses, uykudan dönünce kaçırılanlar da gösterilir
- ICS ve JSON dışa/içe aktarma (ICS: tüm gün `VALUE=DATE`, `RRULE` `UNTIL`/`COUNT`, `VALARM` hatırlatıcı), tüm veriyi silme; bozuk kayıt takvimi kilitlemez, ham veri yedeklenir
- Açık / koyu / sistem teması

## Hızlı başlangıç

Gereksinimler: Flutter SDK (Dart 3.2+); Windows masaüstü için Visual Studio C++ araçları ve Geliştirici Modu; web için Chrome.

```powershell
.\run.ps1          # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome   # cihazı elle seç
.\run.ps1 -Check   # sadece flutter analyze + flutter test
.\publish.ps1      # Windows exe: <repo>\dist\takvim-ve-zamanlayici\ altına
```

Elle: `flutter run -d windows` veya `flutter run -d chrome`.

**Windows exe için Geliştirici Modu gerekir** (Flutter eklentileri sembolik bağlantı ister): `start ms-settings:developers` ile açın, ardından `.\publish.ps1` çalıştırın; kapalıyken betik Türkçe hata ile durur. Geliştirici Modu kapalıysa web hedefi (`.\run.ps1 chrome`) kullanılabilir.

## Kullanım

"Etkinlik" düğmesiyle (ya da doğal dil girişiyle) etkinlik eklenir; renk, tekrar, hatırlatıcı ve tüm gün seçenekleri formdadır. Geniş pencerede sağdaki Odak Zamanlayıcı paneli Pomodoro'yu başlatır; "Bağlı etkinlik" olarak bugünün sıradaki (yoksa son) etkinliği gösterilir. Ayarlar'da tema, veri içe/dışa aktarma, bildirimler ve Pomodoro süreleri bulunur.

| Kısayol (takvim ekranı) | İşlem |
|---|---|
| `N` | Yeni etkinlik |
| `T` | Bugüne git |
| `/` | Ara |
| `Boşluk` | Pomodoro başlat / duraklat |

## Veri ve gizlilik

- Tüm veri `shared_preferences` içindedir: `events_v2` (etkinlikler; eski `events_v1` okunup taşınır), `events_corrupt_backup` (okunamayan kayıt yedeği), `theme_mode`, `pomodoro_settings`, `notifications_enabled`, `pomodoro_notifications`. Windows'ta kullanıcı uygulama verisi klasöründeki `shared_preferences.json`, web'de tarayıcı `localStorage` kullanılır. Konumu değiştiren bir ortam değişkeni yoktur.
- Ağ erişimi yoktur (HTTP istemcisi bağımlılığı yok); hesap, bulut veya analitik yoktur. Dışa aktarma `share_plus` ile sistemin paylaşım/kaydetme akışını kullanır.
- Ayarlar > "KVKK — tüm veriyi sil" tüm etkinlikleri kalıcı siler.
- Ayarlar'daki "Senkronizasyon" bölümü henüz işlevsel değildir: CalDAV adresi/kullanıcı adı yalnızca yerel olarak kaydedilir, iki yönlü senkron "Faz 2, yakında" olarak işaretlidir.

## Mimari / analiz

Teknoloji (pubspec.yaml, sürüm 1.1.0+2): Flutter (Dart ≥ 3.2), flutter_riverpod ^2.5.1, go_router ^18.0.2, intl ^0.20.3 (tr_TR), shared_preferences ^2.2.3, share_plus ^12.0.0, flutter_local_notifications ^18.0.1, timezone ^0.10.1, file_picker ^8.1.2.

```
lib/main.dart, app.dart        bootstrap (tr_TR biçimleri, bildirim servisi), go_router: / takvim, /settings
lib/core/                      date_utils (takvim günü aritmetiği), recurrence (tekrar açılımı),
                               ics_export / ics_import, natural_language_parser, notification_service,
                               time_blocking (odak bloğu üretimi), file_import, theme/
lib/features/calendar/         takvim ekranı, ay/hafta/gün görünümleri, mini ay takvimi, görünüm seçici
lib/features/events/           CalendarEvent modeli, EventsRepository (SharedPreferences), provider, etkinlik formu
lib/features/timer/            Pomodoro durum makinesi (odak/kısa/uzun mola) ve panel
lib/features/settings/         ayarlar ekranı, senkron ayarları (şimdilik yalnızca yerel kayıt)
test/                          tekrar, ICS, hatırlatıcı, kalıcılık ve doğal dil testleri
```

Veri akışı: `EventsRepository.load/save` (JSON, `events_v2`) → `events_provider` → `recurrence` ile görünür aralık için tekrarlar açılır (`EventOccurrence`) → görünümler çizer. Pomodoro odak turu bitince `time_blocking` isteğe bağlı olarak takvime odak bloğu ekler; `NotificationService` hatırlatıcıları (mobil/macOS'ta sistem bildirimi, diğerlerinde `dueReminders` ile uygulama içi) yönetir.

Tasarım kararları: tekrarlar takvim günü/ayı ile ilerler (yaz saati geçişinde saat kaymaz; aylıkta orijinal gün korunur: 31 Oca → 28 Şub → 31 Mar); `Duration(days:)` yerine `addDays` kullanılır; bozuk kayıt okunamazsa yedek anahtara kopyalanır, veri sessizce kaybolmaz; router tek sefer oluşturulur (tema değişince Ayarlar'dan atılmamak için).

## Testler

`flutter test` veya `.\run.ps1 -Check` (analiz + test): `recurrence_ics_reminder_test` (16), `natural_language_test` (4), `recurrence_test` (4), `widget_test` (1) — toplam 25 test çağrısı.

## Bilinen sınırlar

- Windows ve web'de sistem bildirimi yoktur; hatırlatıcılar yalnızca uygulama açıkken uygulama içi uyarı + sistem sesi olarak çalışır.
- CalDAV / Google senkronizasyonu yoktur (yalnızca ayar alanı).
- Saat dilimi Europe/Istanbul (TRT) olarak sabittir; Ayarlar'daki alan bilgi amaçlıdır.
- Dar pencerede / çok genişlikte hafta başlığı kısalabilir (örn. "5–11 Ekim 2…").
- Windows exe'si Geliştirici Modu açık olmadan derlenemez; bu ortamda exe doğrulanmadı.
