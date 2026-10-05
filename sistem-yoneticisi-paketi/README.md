# Sistem Yöneticisi Paketi

Windows için yerel (telemetrisiz) sistem monitörü ve yöneticisi: CPU/RAM/disk/ağ izleme, süreç, servis, başlangıç öğesi ve bağlantı yönetimi (WPF, .NET 10).

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Ana Sayfa / Dashboard:** CPU, RAM, disk ve ağ hızı kartları, 30 sn'lik canlı CPU/RAM grafikleri (LiveCharts2), en çok kaynak kullanan süreçler, disk sürücüleri, duraklatma/yenileme, CSV dışa aktarma ve isteğe bağlı 60 dk geçmiş grafiği
- **CPU/RAM alarmları:** eşik ve süre ayarlanabilir; eşik belirlenen süreden uzun aşılırsa bildirim
- **Süreçler:** arama, sıralama (CPU / RAM / ad / PID), onaylı sonlandırma, **CSV dışa aktarma** (görünen liste, `;` ayraçlı, Excel uyumlu)
- **Servisler:** Windows servislerini başlat / durdur / yeniden başlat (durdurma ve yeniden başlatma onay ister; WMI `Win32_Service` ile)
- **Başlangıç öğeleri:** Registry Run (HKCU/HKLM) + Başlangıç klasörü listeleme ve onaylı kaldırma
- **Başlangıçtan kaldırmayı geri alma:** kaldırılan öğe önce yedeklenir (kısayol silinmez, yedek klasörüne
  taşınır); **↩ Geri Al** en son kaldırılanı geri yükler — uygulama kapatılıp açılsa da çalışır
- **Ağ:** aktif TCP/UDP bağlantıları (IPv4), sahibi olan süreç ve PID, "yalnızca ESTABLISHED" filtresi
- Sistem tepsisi, `Ctrl+Shift+M` global kısayolu (göster/gizle), isteğe bağlı SQLite metrik geçmişi, yüksek kontrast modu, Windows açılışında başlatma, ayarları dışa/içe aktarma, ilk açılış karşılama ve yardım pencereleri

### Güvenlik korumaları

- Sistem için kritik süreçler (csrss, lsass, winlogon, services, svchost, dwm, MsMpEng…), PID ≤ 4,
  erişilemeyen süreçler ve uygulamanın kendisi 🔒 ile gösterilir ve sonlandırılamaz. Koruma sonlandırma anında
  yeniden denetlenir (PID yeniden kullanılmış olsa bile).
- Kritik servisler (RpcSs, DcomLaunch, LSM, EventLog, WinDefend, BFE, Winmgmt, Dnscache…) 🔒 ile gösterilir;
  durdurma / yeniden başlatma engellenir.

## Hızlı başlangıç

```powershell
..\dist\sistem-yoneticisi-paketi\SistemYoneticisiPaketi.exe   # hazır exe (.NET kurulumu gerekmez)

.\run.ps1          # derler ve açar
.\run.ps1 -Check   # tüm testleri çalıştırır
.\publish.ps1      # tek, bağımsız exe → ..\dist\sistem-yoneticisi-paketi\
.\install.ps1      # exe'yi %LocalAppData%\Programs altına kurar + kısayollar (gerekirse önce publish eder)
.\uninstall.ps1    # kaldırır
```

Pencereyi kapatınca tepside kalır; çıkmak için tepsi menüsünden **Çıkış**. Servis ve bazı süreç işlemleri için uygulamayı yönetici olarak çalıştırın (uygulama `asInvoker` ile açılır, kendiliğinden yükselmez).

Gereksinimler: Windows 10/11; geliştirme için .NET 10 SDK (yayınlanan exe için gerekmez).

## Kullanım

Sol menüden modüller arasında geçilir; durum çubuğunda yönetici/standart mod bilgisi görünür.

| Kısayol | İşlev |
|---|---|
| 1 / 2 / 3 / 4 / 5 | Dashboard / Süreçler / Servisler / Başlangıç / Ağ |
| Ctrl+, | Ayarlar |
| Ctrl+Shift+M | Pencereyi göster / gizle (global; Ayarlar'dan değiştirilebilir veya kapatılabilir) |

Ayarlar: metrik geçmişi (24 saat varsayılan saklama), CPU/RAM alarm eşikleri (varsayılan %90, 60 sn), yüksek kontrast, başlangıçta simge durumunda açma, Windows açılışında başlatma, global kısayol.

## Veri ve gizlilik

- Ayarlar (`settings.json`), günlük (`app.log`), metrik geçmişi (`metrics.db`) ve başlangıç yedekleri (`startup-backup\`): `%LocalAppData%\SistemYoneticisiPaketi\`.
- `SISTEM_YONETICISI_DATA_DIR` ortam değişkeniyle konum değiştirilebilir (testler ve taşınabilir kullanım).
- Ağ erişimi ve telemetri yoktur: kodda HTTP istemcisi bulunmaz; tüm metrikler yerel performans sayaçları, WMI ve Win32 API'lerinden okunur. "Windows açılışında başlat" seçeneği yalnızca `HKCU` Run anahtarına yazar.
- Tek örnek: ikinci kez başlatılan kopya hemen kapanır.

## Mimari ve analiz

- **Teknoloji:** .NET 10 (`net10.0-windows`, `RollForward=Major`), WPF; CommunityToolkit.Mvvm 8.4.2, LiveChartsCore.SkiaSharpView.WPF 2.0.5, Hardcodet.NotifyIcon.Wpf 2.0.1, NHotkey.Wpf 3.0.0, Microsoft.Data.Sqlite 10.0.12 + SQLitePCLRaw.lib.e_sqlite3 2.1.13, System.Management 10.0.12. Sürüm 1.3.0.
- **Modüler gezinme:** her ekran bir `IMonitorModule` (Ana Sayfa, Dashboard, Süreçler, Servisler, Başlangıç, Ağ); `ModuleRegistry` sıraya göre kaydeder, sol menü ve tepsi menüsü buradan üretilir. Liste modüllerinin ViewModel'leri ilk açılışta oluşturulur (açılış gecikmesini önlemek için).

```
SistemYoneticisi/
  App.xaml(.cs)                  Tek örnek denetimi, tema, ana pencere
  MainWindow, SettingsWindow,    Ana pencere + tepsi, ayarlar, yardım, hakkında, karşılama
  HelpWindow, AboutWindow, WelcomeWindow
  Modules/                       IMonitorModule, ModuleRegistry, BuiltInModules
  ViewModels/                    Main, Home, Dashboard, Process, Services, Startup, Network
  Views/                         Her modülün XAML görünümü
  Services/
    SystemInfoService            CPU/RAM sayaçları, disk, ağ hızı
    ProcessService               Süreç listesi, koruma kuralları, sonlandırma, CSV
    ServiceManagerService        WMI ile servis listesi ve başlat/durdur
    StartupService               Registry Run + Başlangıç klasörü, yedekleme/geri alma
    NetworkConnectionService     iphlpapi (IPv4 TCP/UDP tabloları)
    MetricsHistoryService        SQLite metrik geçmişi
    AlarmService, SettingsService, LoginStartupService, GlobalHotkeyService, ThemeService, LogService
  Helpers/                       Dönüştürücüler, kısayol ayrıştırıcı, biçimlendirme
SistemYoneticisi.Tests/          xunit testleri
linux/                           Python CLI (psutil)
macos/SistemYoneticisiPaketi/    SwiftUI sürümü
releases/version.json            Sürüm bilgisi
```

**Veri akışı:** `DashboardViewModel` zamanlayıcıyla `SystemInfoService`'ten ölçüm alır → kartlar/grafikler güncellenir → `AlarmService` eşiği değerlendirir → geçmiş açıksa `MetricsHistoryService` SQLite'a yazar. Süreç/servis/başlangıç/ağ ekranları ilk açılışta ve "Yenile" ile ilgili servisten liste çeker; yıkıcı işlemler onay penceresi ve koruma kontrolünden geçer.

**Tasarım kararları:** koruma, kullanıcı arayüzünde değil sonlandırma/durdurma anında yeniden denetlenir; başlangıç öğeleri silinmek yerine yedeğe taşınır; ayarlar düz JSON'dur ve dışa aktarılabilir; testler gerçek süreç, servis veya başlangıç öğelerine dokunmaz (geçici klasör ve test kayıt anahtarı kullanır).

## Testler

`SistemYoneticisi.Tests` altında 25 xunit test metodu (5 `Theory`, toplam 38 durum): güvenlik korumaları (kritik süreç/servis, kendi sürecini sonlandırmayı reddetme), başlangıç öğesi yedekleme/geri alma (klasör ve kayıt defteri), CSV çıktısı, biçimlendirme yardımcıları, metrik geçmişi, alarm, kısayol ayrıştırma, ayarları dışa/içe aktarma, modül kaydı ve geçici veri klasörüyle açılış duman testi.

```powershell
.\run.ps1 -Check
# veya
dotnet test SistemYoneticisi.Tests\SistemYoneticisi.Tests.csproj
```

Diğer platformlar: Linux CLI için `linux/README.md`, macOS sürümü için `macos/SistemYoneticisiPaketi/README.md` (`swift test`).

## Bilinen sınırlar

- Ağ sekmesi yalnızca IPv4 bağlantılarını listeler.
- Servis işlemleri ve bazı süreç bilgileri yönetici yetkisi gerektirebilir; yönetici olmayan modda erişilemeyen süreçler korumalı gösterilir.
- Metrik geçmişi varsayılan olarak kapalıdır (Ayarlar'dan açılır).
- Dashboard'daki RAM kartı ve disk satırlarında dar pencerede metin kırpılabilir.
- Linux ve macOS sürümleri Windows uygulamasının yalnızca basit bir alt kümesidir.
