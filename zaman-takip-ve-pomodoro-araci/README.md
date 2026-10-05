# Odaklanma — Zaman Takip ve Pomodoro

Proje bazlı süre kaydı, günlük rapor ve Pomodoro sayacı sunan Windows masaüstü uygulaması (Flutter + yerel SQLite).

![Ekran görüntüsü](docs/ekran.png)

> Ekran görüntüsü gerçek bir pencere değil, `flutter test` ile bellek içi (in-memory) demo veritabanından alınmış widget görüntüsüdür (Segoe UI / Consolas yazı tipleriyle). Bu uygulama yalnızca Windows'ta çalıştığı ve Windows Geliştirici Modu kapalı olduğu için web/pencere görüntüsü alınamadı.

## Özellikler

- Proje seç → başlat / duraklat / durdur; duraklatılan süre kayda yazılmaz, duraklatma uygulama kapanıp açılınca da korunur
- Günlük toplam, proje dağılımı ve günlük hedef çubuğu
- Pomodoro: odak / kısa mola, 4 seansta bir uzun mola; sayaç duvar saatine göre işler (kare hızı/uyku geride bırakmaz), sekme değiştirince durmaz, uygulama yeniden açılınca kaldığı yerden sürer; faz bitince sesli uyarı; günün domates sayısı saklanır (atlanan odak sayılmaz)
- Raporlar: günler arası gezinme, proje bazlı çubuk grafik, CSV dışa aktarma (Belgeler klasörüne)
- Ayarlar: süreler, günlük hedef, proje ekle / yeniden adlandır / renk / sil
- Bugünkü kayıt listesinden tek tek kayıt silme (onaylı)

## Hızlı başlangıç

Gereksinimler: Flutter SDK (Dart ≥ 3.2), yalnızca Windows hedefi (web desteklenmez); Visual Studio "Desktop development with C++" ve Windows Geliştirici Modu.

```powershell
.\run.ps1          # gerekirse pub get / drift codegen / VS Build Tools kurulumu, sonra Windows'ta açar
.\run.ps1 -Check   # sadece flutter analyze + flutter test
.\publish.ps1      # Windows exe: <repo>\dist\zaman-takip-ve-pomodoro-araci\ altına
```

Elle: `flutter pub get` ve `flutter run -d windows`.

**Windows exe için Geliştirici Modu gerekir** (Flutter eklentileri sembolik bağlantı ister): `start ms-settings:developers` ile açın, ardından `.\publish.ps1` çalıştırın; kapalıyken betik Türkçe hata ile durur. Uygulama Windows'a özgü olduğundan Geliştirici Modu olmadan çalıştırılamaz (web hedefi yoktur).

`lib/data/database.g.dart` depoda hazırdır; tabloları değiştirirseniz `dart run build_runner build` çalıştırın.

## Kullanım

Sol menüden Timer / Pomodoro / Raporlar / Ayarlar arasında geçilir. Timer'da proje seçilip "Başlat" ile kayıt açılır; "Ara Ver" ve "Durdur" ile yönetilir. Pomodoro sekmesi bağımsız bir sayaçtır ve arka planda çalışmaya devam eder. Raporlar günlük toplamı proje bazında gösterir ve o günü CSV'ye aktarır.

| Kısayol | İşlem |
|---|---|
| `Boşluk` | Timer: başlat / durdur; Pomodoro: başlat / duraklat |
| `M` | Timer ↔ Pomodoro |
| `Delete` | Timer: seçili kaydı sil (onay istenir) |
| `←` / `→` | Raporlar: önceki / sonraki gün |

## Veri ve gizlilik

- **Veritabanı:** `Belgeler\time_tracking.sqlite` (Drift/SQLite; projeler ve süre kayıtları). Konumu değiştiren bir ortam değişkeni yoktur.
- **Ayarlar ve durum:** `shared_preferences` (süreler `work_min`, `break_min`, `long_break_min`, günlük hedef `goal_hours`, duraklatma bilgisi `timer_pause`, Pomodoro durumu `pomodoro_state`) — kullanıcı uygulama verisi klasöründeki `shared_preferences.json`.
- **CSV dışa aktarma:** `Belgeler\odaklanma-yyyy-MM-dd.csv`.
- Ağ erişimi, hesap ve analitik yoktur; tüm veri cihazda kalır.

## Mimari / analiz

Teknoloji (pubspec.yaml, sürüm 1.0.0+1): Flutter (Dart ≥ 3.2), flutter_riverpod ^2.5.1, go_router ^18.0.2, drift ^2.20.0 + sqlite3_flutter_libs ^0.5.24 (drift_dev / build_runner ile kod üretimi), path_provider ^2.1.3, path ^1.9.0, intl ^0.20.3, shared_preferences ^2.2.3.

```
lib/main.dart, app.dart        SharedPreferences yüklenir; go_router ShellRoute: /timer, /pomodoro, /reports, /settings
lib/data/                      AppDatabase (Projects, TimeEntries; schemaVersion 2), database.g.dart, databaseProvider
lib/features/timer/            süre kaydı ekranı, PauseStore (duraklatma bilgisi kalıcılığı)
lib/features/pomodoro/         PomodoroNotifier (duvar saatine göre durum makinesi) ve ekran
lib/features/reports/          günlük rapor, çubuk grafik, CSV dışa aktarma
lib/features/settings/         süreler, günlük hedef, proje yönetimi
lib/core/                      ayarlar (SharedPreferences), tema, süre biçimleme, ortak bileşenler (AppShell, OdCard)
test/                          veritabanı, Pomodoro/oturum mantığı ve widget testleri
```

Veri akışı: ekran → `databaseProvider` (`AppDatabase`) → `time_tracking.sqlite`; çalışan Pomodoro ve duraklatma durumu her geçişte `shared_preferences`'a yazılır, açılışta bitiş anına göre geri yüklenir.

Tasarım kararları: sayaç değeri tik sayısından değil duvar saatinden (`endAt` / başlangıç − duraklatmalar) hesaplanır, böylece Timer gecikmesi, küçültülmüş pencere veya uyku sonucu bozmaz; yabancı anahtarlar `PRAGMA foreign_keys = ON` ile açılır (proje silinince kayıtlar da silinir); açık kayıt sorgusu `limit(1)` kullanır (çift "Başlat" tıklamasına dayanıklı); migration `colorArgb` sütununu ekler (v1 → v2).

## Testler

`flutter test` veya `.\run.ps1 -Check` (analiz + test): `pomodoro_and_session_test` (11), `database_test` (1), `widget_test` (1) — toplam 13 test çağrısı; veritabanı testleri `AppDatabase.test()` (bellek içi SQLite) kullanır.

## Bilinen sınırlar

- Yalnızca Windows; web ve mobil hedef yoktur.
- Windows exe'si Geliştirici Modu açık olmadan derlenemez; bu ortamda exe doğrulanmadı.
- Dar listelerde uzun proje adı ile süre etiketi birbirine yaklaşabilir ("1s 30dk" etiketi proje adına yapışabilir).
