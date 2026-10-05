# Metadata Temizleyici

Fotoğraf ve PDF'lerdeki (exiftool kuruluysa videolardaki) EXIF/GPS/XMP/IPTC metadata'sını yerelde toplu
temizleyen PySide6 masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Sürükle-bırak veya klasör taraması (alt klasörler dahil), metadata önizleme ve risk etiketleri
- Presetler: sosyal medya, yalnızca GPS, kamera bilgisi, özel tag listesi
- Paralel toplu temizleme (3 worker), simülasyon modu, `.bak` yedek ve geri yükleme
- CSV audit raporu, JSON metadata export, önce/sonra karşılaştırma
- Klasör izleme (yeni dosyaları otomatik temizler) + sistem tepsisi
- CLI: `python cli.py read|clean|check|restore|presets`
  - `clean --copy`: orijinale dokunmadan `ad_clean.uzantı` kopyası yazar (varsa `ad_clean2…`)
  - `check`: yüksek riskli metadata kalan dosyaları listeler, varsa çıkış kodu 1 (betik/CI kontrolü)
  - Herhangi bir dosya temizlenemezse `clean` çıkış kodu 1 döner

## Neler temizlenir (exiftool olmadan, yerel motor)

| Biçim | Silinen | Korunan | Yöntem |
|---|---|---|---|
| JPEG | EXIF (GPS, seri no, MakerNote), XMP, IPTC/Photoshop (APP13), yorum, diğer APPn blokları, EOI sonrası ek veri | ICC renk profili, Adobe renk bloğu, yön etiketi | Kayıpsız (piksel verisi bayt bayt aynı) |
| PNG | tEXt/zTXt/iTXt (XMP dahil), eXIf, tIME | ICC, şeffaflık, APNG kareleri | Kayıpsız |
| WebP | EXIF, XMP | ICC, alfa, animasyon | Kayıpsız |
| TIFF / HEIC / BMP | EXIF, XMP, IPTC, açıklama tag'leri | ICC, tüm TIFF sayfaları | Yeniden kaydetme (TIFF kayıpsız sıkıştırma, HEIC kalite 95) |
| PDF | Belge bilgisi (/Info: yazar, oluşturan, başlık…), XMP akışları | Sayfalar | pypdf ile yeniden yazma — eski nesneler dosyada kalmaz |

- "Tümünü temizle" modunda yalnızca EXIF yön etiketi bırakılır (yoksa dik fotoğraflar yan görünür).
- GPS/kamera/preset modları JPEG/PNG/WebP'de seçili tag'leri siler, gerisini (Exif alt IFD dahil) korur; PDF'te
  yalnızca "tümünü temizle" desteklenir.
- Yazım önce geçici dosyaya yapılır, sonra yerine taşınır: hata olursa orijinal bozulmaz. `.bak` yedeği ilk
  temizlikte alınır ve sonraki temizliklerde ezilmez.
- Video: exiftool yoksa videolar kuyruğa alınmaz; atlanan video sayısı ve kurulum ipucu durum çubuğunda / CLI'da
  gösterilir (ffmpeg gerekmez).

## Çalıştırma

```powershell
.\run.ps1
```

İlk çalıştırmada `.venv` oluşturur ve `requirements.txt` kurar. Manuel: `pip install -r requirements.txt` ve `python main.py`.

- Test: `.\run.ps1 -Check`
- Exe üretme: `.\publish.ps1` → `dist\metadata-temizleyici\` (repo kökünde; `MetadataTemizleyici.exe` + `_internal`).
  `sidecar\exiftool.exe` varsa pakete eklenir.

## Gereksinimler

- Python 3.11+
- PySide6, Pillow, pillow-heif, pypdf, typer, rich, watchdog
- İsteğe bağlı exiftool (video ve RAW gibi diğer biçimler için): PATH'te olmalı veya
  `.\scripts\install-exiftool.ps1` ile `sidecar\` klasörüne kurulmalı. Yoksa görseller ve PDF'ler yerel motorla temizlenir
  (PDF her zaman yerel motorla: exiftool'un PDF düzenlemesi eski metadata'yı dosyada bırakır).

Ayarlar `~/.metadata-temizleyici/settings.json` dosyasında tutulur.

## Klasörler

- `main.py` — GUI giriş noktası, `cli.py` — komut satırı
- `ui/` — ana pencere ve widget'lar
- `utils/metadata.py` — okuma/temizleme (exiftool veya yerel motor), `utils/local_strip.py` — kayıpsız JPEG/PNG/WebP, PDF temizliği, `utils/batch_worker.py` — paralel işlem, `utils/watcher.py` — klasör izleme
- `sidecar/` — gömülü exiftool için yer
- `scripts/ekran_goruntusu.py` — `docs/ekran.png`'yi uydurma fotoğraflarla ekrana çıkmadan üretir

## Bilinen sınırlar

- CLI çıktısı bir dosyaya / boruya yönlendirildiğinde (UTF-8 olmayan Windows kod sayfası) Türkçe karakter ve
  `✓` yüzünden `UnicodeEncodeError` ile çıkabilir; geçici çözüm: `$env:PYTHONIOENCODING = "utf-8"`.
- 1280×800 ve altındaki pencere boyutlarında preset çipleri ve dosya düğmelerinin metni kırpılıyor
  (ekran görüntüsü 1440×960'ta alındı).
