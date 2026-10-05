# Otomasyon ve Makro Aracı

Fare/klavye adımlarını kaydedip düzenlemenizi ve tekrar oynatmanızı sağlayan Windows (WPF) makro aracı; güvenli mod ve fiziksel Esc ile acil durdurma içerir.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Global hook ile kayıt: sol tık, yazılan metin, özel tuşlar (noktalama dahil) ve aradaki bekleme süreleri; kayıt duraklatılabilir
- Adım editörü: tıkla (koordinat), metin yaz, bekle, tuş bas, UI öğesine tıkla (UIAutomation), pencere başlığı koşulu, atla.
  Adım taşınınca/silinince koşul ve atlama hedefleri doğru adımı izler
- "Öğe seç": 3 saniye içinde fareyi getirdiğiniz UI öğesinin adını/AutomationId'sini adıma aktarır
- Değişkenler: `{{clipboard}}`, `{{date}}`, `{{time}}`, `{{datetime}}`, `{{user}}`, `{{env:AD}}`
- Profil başına global kısayol (ör. `Ctrl+Alt+F1`) ve gün/saat zamanlayıcısı; kısayol çakışması listelenir ve çözülebilir
- **Tekrar sayısı:** makroyu N kez oynatır; `0` = Esc ile durdurulana kadar
- **Çoğalt:** makronun kısayolsuz bir kopyasını oluşturur (kayda başlamadan önce mevcut adımları korumak için)
- Güvenli mod (yalnızca odaklı pencere / belirli süreç; her girdiden hemen önce yeniden doğrulanır), riskli adımlarda (metin yaz, UI tıkla, Enter/Delete/Backspace/Tab) onay
- **Acil durdurma:** oynatma sırasında fiziksel `Esc` tuşu, uygulama odakta olmasa ve bekleme adımı sürse bile makroyu anında durdurur
  (makronun kendi gönderdiği Esc durdurmaz)
- Tek adım (debug) çalıştırma, oynatma ilerlemesi ve durum çubuğu
- Kaydedilmemiş değişiklikler kapatırken sorulur; kayıt sürerken kapatılırsa kaydedilen adımlar saklanır
- SQLite ile saklama, `.macro.json` içe/dışa aktarma; ilk açılışta iki örnek makro oluşturulur

## Hızlı başlangıç

```powershell
..\dist\otomasyon-ve-makro-araci\OtomasyonMakro.exe   # hazır exe (.NET kurulumu gerekmez)

.\run.ps1          # derler ve başlatır
.\run.ps1 -Check   # yalnızca testleri çalıştırır (xunit)
.\publish.ps1      # tek dosya, self-contained exe → ..\dist\otomasyon-ve-makro-araci\
.\install.ps1      # exe'yi %LOCALAPPDATA%\Programs\OtomasyonMakro altına kurar, masaüstü/Başlat kısayolu oluşturur
.\uninstall.ps1    # kaldırır (makrolar korunur)
```

Gereksinimler: Windows 10/11; geliştirme için .NET 10 SDK.

## Kullanım

1. Sol listeden bir makro seçin veya **+** ile yenisini oluşturun.
2. **Kayda başla** (veya `Ctrl+Alt+M`) ile adımları kaydedin; **Durdur ve kaydet** ile bitirin. Ya da adımları `+ Tık`, `+ Metin`, `+ Bekle`, `+ Tuş`, `+ UI`, `+ Koşul` ile elle ekleyin.
3. Sağ paneldeki **Adım detayı** ve **Makro ayarları** bölümünden adımı, kısayolu, hedef süreci (`*` = odaklı pencere), tekrar sayısını ve zamanlayıcıyı düzenleyin; **Kaydet**.
4. **Çalıştır** (`F5`) veya **Tek adım** (`Shift+F5`) ile oynatın. Oynatma sırasında `Esc` her zaman durdurur.

| Kısayol | Bağlam | İşlev |
|---|---|---|
| Ctrl+Alt+M | Global | Kayıt başlat / durdur |
| Esc | Global (oynatma sırasında) | Acil durdur |
| F5 | Ana pencere | Makroyu çalıştır |
| Shift+F5 | Ana pencere | Tek adım |
| Ctrl+S | Ana pencere | Kaydet |
| Profil kısayolu (ör. Ctrl+Alt+F1) | Global | İlgili makroyu çalıştır |

## Veri ve gizlilik

- Makrolar `%LOCALAPPDATA%\OtomasyonMakro\macros.db` içinde (hata günlüğü `crash.log` aynı klasörde).
- `OTOMASYONMAKRO_DATA_DIR` ortam değişkeniyle konum değiştirilebilir. Eski sürümün exe yanındaki `data\macros.db` dosyası ilk açılışta buraya kopyalanır.
- Ağ erişimi yoktur; kodda HTTP istemcisi bulunmaz, telemetri yoktur. Kayıt sırasında yazdığınız tuşlar yalnızca makro adımı olarak yerel veritabanına yazılır (parola gibi hassas girdileri kaydetmemeye dikkat edin).
- `{{clipboard}}` ve `{{env:AD}}` değişkenleri yalnızca oynatma anında yerel pano/ortam değişkenini okur.

## Mimari ve analiz

- **Teknoloji:** .NET 10 (`net10.0-windows`, `RollForward=Major`), WPF; CommunityToolkit.Mvvm 8.4.2, FlaUI.UIA3 5.0.0 (UIAutomation), InputSimulatorStandard 1.0.0 (girdi gönderme), Microsoft.Data.Sqlite 10.0.12 + SQLitePCLRaw.lib.e_sqlite3 2.1.13, NHotkey.Wpf 4.0.0 (global kısayollar). Sürüm 2.0.0.

```
OtomasyonMakro/
  App.xaml(.cs)                 Yakalanmayan hata → crash.log + mesaj kutusu
  MainWindow, HotkeysWindow,    Ana pencere, kısayol atamaları, kayıt göstergesi
  RecordOverlayWindow
  ViewModels/MainViewModel      Profiller, kayıt/oynatma komutları, kısayol kaydı, içe/dışa aktarma
  Models/                       MacroProfile, MacroStep (7 adım türü), HotkeyAssignment, UiElementInfo
  Services/
    GlobalHookService           WH_MOUSE_LL / WH_KEYBOARD_LL kancaları
    MacroRecorder               Ham olayları adımlara çevirir (metin tamponu, bekleme süreleri)
    PlaybackService             Adımları yürütür: koşul/atlama, tekrar, güvenli mod doğrulaması
    MacroInput (IMacroInput)    Masaüstüne girdi gönderilen tek yer (testlerde sahtesi kullanılır)
    EmergencyStopMonitor        Ayrı thread'de fiziksel Esc dinleyen kanca
    ScheduleService             30 sn'de bir gün/saat zamanlayıcısı kontrolü
    UIAutomationService         UI öğesi bulma/tıklama/seçme
    DatabaseService             SQLite şeması, geçiş (migration), örnek veri
  Helpers/                      VariableResolver, Win32Api, dönüştürücüler
OtomasyonMakro.Tests/           xunit testleri
assets/                         İkonlar ve manifest.json
```

**Veri akışı:** kayıt: Win32 kancası → `MacroRecorder` → `MacroStep` listesi → `DatabaseService` (SQLite). Oynatma: `PlaybackService` adımları sırayla yürütür → her girdiden önce odaklı pencere/hedef süreç yeniden doğrulanır → `IMacroInput` ile girdi gönderilir; `EmergencyStopMonitor` iptal belirtecini tetikleyebilir.

**Tasarım kararları:** oynatmanın masaüstüne dokunduğu tek nokta `IMacroInput` arayüzüdür, böylece testler gerçek girdi göndermez; acil durdurma UI thread'inden bağımsız bir kanca thread'indedir; zamanlayıcı tetiklemesi kayıt veya oynatma sürerken atlanır; veri yazılabilir `%LOCALAPPDATA%` altındadır.

## Testler

`OtomasyonMakro.Tests` altında 27 xunit test metodu (4 `Theory`, toplam 40 durum) bulunur: oynatma ve kayıt (sahte giriş katmanı ve sentetik olaylarla), koşul/atlama, güvenli mod, tuş adı çözümleme, değişken çözümleyici. Hiçbir test masaüstüne gerçek fare/klavye girdisi göndermez.

```powershell
.\run.ps1 -Check
# veya
dotnet test OtomasyonMakro.Tests\OtomasyonMakro.Tests.csproj
```

## Bilinen sınırlar

- Yalnızca Windows; koordinat tabanlı adımlar ekran çözünürlüğü/düzenine bağımlıdır.
- Kayıtta yalnızca sol tık yakalanır; yalnızca A-Z, 0-9, numpad ve boşluk metne girer, noktalama fiziksel tuş olarak kaydedilir ve Shift+rakam ("!") Shift'siz oynar (klavye düzenine duyarlı çeviri yoktur).
- Ctrl/Alt basılıyken gelen tuşlar (kısayollar) kaydedilmez.
- Zamanlayıcı yalnızca uygulama açıkken çalışır.
