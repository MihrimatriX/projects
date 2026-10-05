# Hızlı Ekran Kaydı ve GIF Oluşturucu

Ekranın bir bölgesini kaydedip kırpan ve GIF ya da MP4 olarak kaydeden Windows (WPF) uygulaması; tüm işlem yerelde ffmpeg ile yapılır.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Tam ekran yarı saydam katman üzerinde sürükleyerek bölge seçme, taşıma ve köşelerden boyutlandırma (en az 120×80 px); çoklu monitör sanal ekranını kapsar
- 10 / 15 / 24 FPS, imleci gösterme/gizleme, GIF veya MP4 hedef formatı
- Kayıt süresi sayacı; **Ctrl+Alt+R** global kısayolu ile kayıt başlatma / durdurma
- Kayıttan sonra kırpma penceresi: timeline üzerinde başlangıç/bitiş tutamakları, oynatma, süre ve dosya boyutu tahmini
- GIF (iki geçişli palet optimizasyonlu) veya MP4 (H.264) olarak dışa aktarma
- Son 10 kaydın geçmişi (SQLite), küçük resim ve detay paneli (format, çözünürlük, süre, boyut). Listeden düşen eski kayıtların dosyaları silinmez, kayıt klasöründe kalır
- **Video aç… (Ctrl+O) / sürükle-bırak:** var olan bir videoyu (MP4, MOV, MKV, AVI, WEBM, WMV) kırpıp GIF/MP4'e dönüştürme
- **Panoya kopyala (Ctrl+C):** seçili GIF/MP4'ü dosya olarak panoya alır; sohbete veya klasöre doğrudan yapıştırılır
- Kayıt klasörünü açma, kaydı varsayılan uygulamayla açma, silme, geçmişi temizleme
- ffmpeg yoksa durum çubuğunda ve işlem denendiğinde `winget` kurulum talimatı gösterilir

## Hızlı başlangıç

```powershell
# Hazır exe (repo kökündeki dist klasörü; .NET kurulumu gerekmez)
..\dist\hizli-ekran-kaydi-ve-gif-olusturucu\EkranKaydi.exe

.\run.ps1          # derler ve başlatır (-Release, -NoBuild seçenekleri var)
.\run.ps1 -Check   # yalnızca testleri çalıştırır
.\publish.ps1      # tek dosya, self-contained exe üretir → ..\dist\hizli-ekran-kaydi-ve-gif-olusturucu\
```

Gereksinimler: Windows 10/11; geliştirme için .NET 10 SDK. Yayın çıktısı `EkranKaydi.exe` + `ffmpeg\` alt klasörüdür.

### ffmpeg

Uygulama ffmpeg'i şu sırayla arar: kendi klasöründeki `ffmpeg\` alt klasörü (depodaki `EkranKaydi/ffmpeg.exe` ve `ffprobe.exe` derlemede buraya kopyalanır), exe klasörü, `PATH`, winget kurulum konumları (`%LOCALAPPDATA%\Microsoft\WinGet\Links`, `Packages\Gyan.FFmpeg*`). Bulunamazsa:

```powershell
winget install Gyan.FFmpeg
```

Kurulumdan sonra uygulamayı yeniden başlatmak gerekmez. ffmpeg olmadan da geçmiş, önizleme, dosyayı açma, panoya kopyalama, kayıt klasörünü açma ve silme çalışır.

## Kullanım

1. **Yeni kayıt** düğmesi ya da **Ctrl+Alt+R** ile bölge seçim katmanını açın; bölgeyi çizin/taşıyın/boyutlandırın, FPS ve formatı seçin.
2. **Enter** veya **R** ile kaydı başlatın; **Ctrl+Alt+R** veya durdur düğmesiyle bitirin.
3. Kırpma penceresinde başlangıç/bitişi ayarlayın, **GIF Oluştur** (veya MP4) ile dışa aktarın; kayıt geçmişe eklenir.
4. Geçmişten bir kaydı seçip önizleyin, panoya kopyalayın, Trim editöründe yeniden açın veya silin.

| Kısayol | Bağlam | İşlev |
|---|---|---|
| Ctrl+Alt+R | Global | Kayıt katmanını aç / kaydı başlat-durdur |
| Ctrl+O | Ana pencere | Video aç (dönüştürme için) |
| Ctrl+C | Ana pencere | Seçili kaydı dosya olarak panoya kopyala |
| Enter / R | Bölge seçimi | Kaydı başlat |
| Esc | Bölge seçimi | İptal |
| Boşluk | Kırpma penceresi | Oynat / duraklat |
| Ctrl+S | Kırpma penceresi | Dışa aktar |
| Çift tık | Geçmiş listesi | Kaydı varsayılan uygulamayla aç |

## Veri ve gizlilik

- Kayıtlar, veritabanı ve küçük resimler: `%LOCALAPPDATA%\EkranKaydi\` (`Recordings\`, `recordings.db`, `thumbnails\`, `temp\`, hata günlüğü `crash.log`).
- `EKRANKAYDI_DATA_DIR` ortam değişkeniyle konum değiştirilebilir (testler de bunu kullanır). Eski sürümün exe yanındaki `data\` geçmişi ilk açılışta buraya kopyalanır.
- Ağ erişimi yoktur: kodda HTTP istemcisi bulunmaz, kayıt ve dönüştürme yalnızca yerel ffmpeg süreçleriyle yapılır. Telemetri yoktur.

## Mimari ve analiz

- **Teknoloji:** .NET 10 (`net10.0-windows`, `RollForward=Major`), WPF; CommunityToolkit.Mvvm 8.4.2, FFMpegCore 5.5.0 (ffprobe ile medya bilgisi), Microsoft.Data.Sqlite 10.0.12 + SQLitePCLRaw.lib.e_sqlite3 2.1.13, NHotkey.Wpf 4.0.0 (global kısayol). Test: xunit.
- **Kayıt:** ffmpeg `gdigrab` ile masaüstünün seçili bölgesini yakalar (`libx264 -preset ultrafast -pix_fmt yuv420p`); durdurmak için ffmpeg'in stdin'ine `q` yazılır (süreç öldürülmez, böylece MP4 düzgün kapanır).
- **Dışa aktarma:** MP4 doğrudan taşınır; GIF için `palettegen` + `paletteuse` (bayer dither) iki geçişli filtre kullanılır, kırpma ffmpeg ile yapılır.

```
EkranKaydi/
  App.xaml(.cs)            Yakalanmayan hata → crash.log + mesaj kutusu
  MainWindow.xaml(.cs)     Ana pencere: geçmiş listesi, önizleme, sürükle-bırak
  ViewModels/MainViewModel Komutlar, global kısayol, panoya kopyalama, geçmiş
  Views/RecorderWindow     Tam ekran bölge seçimi ve kayıt kontrolü
  Views/TrimWindow         Kırpma/önizleme ve dışa aktarma
  Controls/TrimTimeline    Özel timeline denetimi
  Services/FfmpegService   ffmpeg bulma, kayıt, kırpma, GIF, medya bilgisi
  Services/DatabaseService SQLite geçmişi (en fazla 10 kayıt), eski veri taşıma
  Services/AppPaths        Veri klasörü ve EKRANKAYDI_DATA_DIR
  Models/ Helpers/ Themes/ Veri modeli, dönüştürücüler, koyu tema
EkranKaydi.Tests/          xunit testleri
assets/                    İkonlar, launcher.json, manifest.json
```

**Veri akışı:** bölge seçimi → ffmpeg ile geçici `temp\temp_recording.mp4` → kırpma penceresi → ffmpeg ile `Recordings\recording_<tarih>.gif|mp4` → `recordings.db` kaydı + küçük resim → ana pencere listesi.

**Tasarım kararları:** ffmpeg'e bağımlılık tek yerde (`FfmpegService`) toplanır ve yoksa uygulama yine açılır; geçmiş yalnızca 10 kayıtla sınırlıdır ama dışa aktarılan dosyalar sessizce silinmez; yazılabilir veriler Program Files'ta salt okunur olabilen exe klasörü yerine `%LOCALAPPDATA%` altındadır; tek dosya yayınında ffmpeg `ffmpeg\` alt klasöründe tutulur (üst düzeyde tek exe kalır).

## Testler

`EkranKaydi.Tests/CoreTests.cs` içinde 15 xunit test metodu (2 `Theory`, toplam 21 durum) bulunur: SQLite geçmişi (sıralama, 10 kayıt sınırı, silme/temizleme, eski veriyi taşıma, kalıcılık), veri klasörü ve ffmpeg arama, Türkçe kurulum mesajı, genişlik normalleştirme, desteklenen video uzantıları, gerçek ffmpeg ile kırpma/GIF/küçük resim akışı ve hata yüzeyleme, geçici veri klasörüyle açılış duman testi.

```powershell
.\run.ps1 -Check
# veya
dotnet test EkranKaydi.Tests\EkranKaydi.Tests.csproj
```

## Bilinen sınırlar

- Yalnızca Windows; kayıt `gdigrab` ile yapıldığından ses kaydedilmez.
- Geçmiş son 10 kayıtla sınırlıdır (ana penceredeki "Son kayıtlar (10)" başlığı sabit metindir).
- Kayıt, ffmpeg `ultrafast` ayarıyla yapıldığından MP4 dosyaları büyük olabilir; kırpma penceresi GIF boyutunun 10 MB'ı aşabileceği konusunda uyarır.
- Kırpma penceresindeki boyut tahmini kaba bir orandır.
