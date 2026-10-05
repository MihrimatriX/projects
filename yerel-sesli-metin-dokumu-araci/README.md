# Yerel Sesli Metin Dökümü Aracı

Ses dosyalarını tamamen bu bilgisayarda (faster-whisper / Whisper, CPU) metne çeviren PySide6 masaüstü uygulaması.
Ses hiçbir sunucuya gönderilmez.

![Ekran görüntüsü](docs/ekran.png)

*Ekran görüntüsü, uygulamayı demo bir transkript ve geçmişle gösterir; gerçek bir ses kaydı veya model kullanılmamıştır.*

## Özellikler

- WAV, MP3, M4A, OGG, OPUS, FLAC (ve WebM/MP4 ses) dosyası açma (`Ctrl+O`); transkript Türkçe
- Sistemde ffmpeg gerekmez: ses PyAV ile çözülür (kendi FFmpeg kütüphaneleri pakette)
- Model seçimi: tiny / base / small (varsayılan) / medium — seçim kalıcıdır
- Model exe'ye gömülmez; ilk kullanımda bir kez `%LOCALAPPDATA%\YerelSesliMetinDokumu\models\<model>` altına
  indirilir (Türkçe ilerleme yüzdesi; yarım indirme model sayılmaz, bağlantı yoksa açık hata mesajı)
- Gerçek segment zaman damgaları; oynatıcı, gerçek ses dalga formu, cümleye tıklayınca o konuma atlama
- TXT / SRT / VTT dışa aktarma
- Ses dosyasını exe'nin üzerine bırakma / "Birlikte aç" (`SesliMetinDokumu.exe kayit.mp3`) — hemen dökülür
- Pencere kapatılınca süren transkripsiyon iptal edilir
- Son 50 işin geçmişi (yalnızca dosya adı/yolu ve süre; transkript saklanmaz), geçmiş sayfasında dosya adıyla arama

## Hızlı başlangıç

```powershell
dist\yerel-sesli-metin-dokumu-araci\SesliMetinDokumu.exe   # .\publish.ps1 ile üretilmiş sürüm
.\run.ps1          # uygulamayı aç (ilk çalıştırmada .venv oluşturur, requirements.txt kurar)
.\run.ps1 -Check   # testleri çalıştır (pytest; model indirmez, internete çıkmaz)
.\publish.ps1      # testler + PyInstaller -> dist\yerel-sesli-metin-dokumu-araci\ (tüm klasörü birlikte taşıyın)
```

Manuel: `pip install -r requirements.txt` ve `python main.py`. Gereksinim: Python 3.11+ (PySide6, faster-whisper).

## Kullanım

1. **Ctrl+O** (ya da araç çubuğundaki klasör simgesi) ile ses dosyasını seçin; dosya hemen yerelde dökülür.
   İlk kullanımda seçili model indirilir (üstteki açılır listeden tiny / base / small / medium seçilir).
2. Segmentler geldikçe sağdaki **Transkript** listesinde zaman damgasıyla görünür; bir cümleye ya da dalga formuna
   tıklayınca oynatıcı o konuma atlar.
3. **.txt / .srt / .vtt** düğmeleriyle dışa aktarın. **Geçmiş** sayfasından eski bir işi arayıp ana alanda yeniden açabilir
   (dosya hâlâ yerindeyse yeniden dökülür) ya da silebilirsiniz.

| Kısayol | İşlev |
| --- | --- |
| `Ctrl+O` | Ses dosyası aç |
| `Ctrl+H` | Geçmiş panelini aç / kapat |
| `Space` | Oynat / duraklat |
| `←` / `→` | 5 sn geri / ileri |

## Veri ve gizlilik

- Tanıma tamamen yerelde, CPU üzerinde (CTranslate2 `int8`, ses dilinin Türkçe olduğu varsayılır, sessizlik
  ayıklama (VAD) açık) çalışır; ses ve transkript hiçbir sunucuya gönderilmez.
- Ağ erişimi yalnızca model indirmesi içindir: seçilen modelin dosyaları Hugging Face (`Systran/faster-whisper-<boyut>`)
  adresinden bir kez indirilir (tiny ~75 MB, base ~145 MB, small ~484 MB, medium ~1,5 GB). Yarım indirme `.part`
  olarak kalır ve model sayılmaz. Model indirildikten sonra uygulama çevrimdışı çalışır.
- Model ve ayarlar: `%LOCALAPPDATA%\YerelSesliMetinDokumu\` (`models\<boyut>`, `settings.ini`; konum `LOCALAPPDATA`
  ortam değişkeniyle değiştirilebilir). Geçmiş veritabanı: `~/.yerel-sesli-metin-dokumu/history.db` (SQLite; yalnızca dosya
  adı, yol, süre ve tarih — transkript metni saklanmaz).

## Mimari / analiz

Teknoloji: Python 3.11+ (geliştirme ortamı Python 3.13), PySide6 >=6.7.0 (Qt Multimedia ile oynatma), faster-whisper
>=1.1.0 (CTranslate2, PyAV, onnxruntime), testler pytest >=8.0.0, exe için PyInstaller >=6.10.

```
main.py                 giriş noktası (QApplication, simge, komut satırından gelen ses dosyası)
ui/main_window.py       WorkspacePage (oynatıcı, dalga formu, transkript, dışa aktarma), HistoryPage, MainWindow,
                        TranscribeWorker (QThread)
ui/widgets.py           WaveformWidget, SegmentRow, NavToolbar, InfoBanner
ui/theme.py             koyu tema (QSS)
utils/transcribe.py     ses çözme (PyAV), model indirme, faster-whisper çağrısı, TXT/SRT/VTT biçimleyiciler
utils/job_history.py    SQLite iş geçmişi (son 50)
utils/time_fmt.py       süre / tarih biçimleme
test/                   pytest (motor sınırda taklit edilir; indirme yerel http.server'dan)
```

Veri akışı: dosya seçimi → `TranscribeWorker` → `load_audio` (PyAV, 16 kHz mono) → `ensure_model` (gerekirse indir) →
`faster_whisper.WhisperModel.transcribe` segmentleri tanındıkça üretir → ilerleme sinyalleri arayüze ulaşır →
`TranscriptResult` (metin, segmentler, dalga formu tepe değerleri) → liste, dalga formu, dışa aktarma ve geçmiş kaydı.

Tasarım kararları: motor tek bir sınır fonksiyonunda (`_run_whisper`) tutulur, böylece testler gerçek model olmadan çalışır;
model dosyaları sırayla ve büyük dosya en sona gelecek şekilde `.part` ile indirilip tamamlanınca yerine taşınır;
PyAV'ın `faster_whisper.audio.decode_audio` ile uyumsuzluğu nedeniyle ses doğrudan PyAV ile çözülür; çalışan iş parçacığı
varken pencere kapanırsa iş iptal edilip beklenir.

## Testler

- pytest: 14 test — `test/test_transcribe.py` (11: WAV/MP3 çözme, düşük örnekleme hızı, bozuk/boş dosya hataları,
  taklit motorla boru hattı ve iptal, TXT/SRT/VTT çıktıları, model indirme ilerlemesi/önbelleği, başarısız veya eksik
  indirme, bilinmeyen model) ve `test/test_history_ui.py` (3: geçmiş sınırı, süre biçimleme, ana pencere akışı ve dışa aktarma)
- Çalıştırma: `.\run.ps1 -Check` ya da `.venv\Scripts\python.exe -m pytest -q`. Gerçek model indirilmez, internete çıkılmaz;
  gerçek ses/model ile uçtan uca doğrulama otomatik testlerde yoktur.

## Bilinen sınırlar

- Transkripsiyon dili Türkçe olarak sabittir (arayüzde dil seçimi yok); konuşmacı ayrımı ve çeviri yoktur.
- Yalnızca CPU (`int8`) ile çalışır; `small`/`medium` modeller uzun kayıtlarda yavaş olabilir. Tanıma ilerlemesi segment
  zamanına göre tahmin edilir.
- Mikrofondan canlı kayıt yok; yalnızca mevcut ses dosyaları dökülür.
- Geçmiş transkript saklamaz: eski bir işi açmak ses dosyasının hâlâ aynı yolda olmasını ve yeniden dökülmesini gerektirir.
- Windows için yazılmış ve denenmiştir; exe PyInstaller `--onedir` çıktısıdır (kurulum sihirbazı yok). İlk model
  indirmesi için internet gerekir.
