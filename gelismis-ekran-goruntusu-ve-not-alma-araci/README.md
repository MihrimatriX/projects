# Gelişmiş Ekran Görüntüsü ve Not Alma

Windows için ekran yakalama, üzerine işaret/not ekleme ve çevrimdışı OCR aracı (WPF).

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Yakalama**
- Global kısayol (varsayılan **Ctrl + Alt + A**; Ayarlar'dan Ctrl+Shift+A, Ctrl+Alt+S, Ctrl+Shift+S, Print Screen) ya da "Yeni yakalama" / `Ctrl+N`
- Bölge veya tam ekran (tüm monitörler, yüksek DPI); `Enter` / **Yakala** onaylar, `Esc` / sağ tık / **İptal** vazgeçer
- **Görsel aç** (`Ctrl+O`): var olan PNG/JPG/BMP/GIF/TIFF dosyasını düzenleyicide aç

**Düzenleyici**
- Ok, dikdörtgen, kalem, metin, pikselleştirme (`1`–`5`), `Ctrl+Z` geri al
- `Ctrl+S` kaydet (PNG + OCR + geçmiş), `Ctrl+C` panoya kopyala, OCR paneli ve metni kopyalama
- Kaydedilmemiş işaretlemeler varken kapatma onay ister

**Geçmiş**
- OCR metni / dosya adına göre arama (`Ctrl+F`, `Esc` temizler), "eşleşen kayıt yok" durumu
- Önizleme + OCR metni, **Düzenle** (`Enter`), Klasörde göster, Görseli/Metni kopyala, Sil (`Delete`, onaylı), Geçmişi temizle
- Geçmiş sınırı ayarlanabilir (20/50/100/500); sınırı aşan en eski kayıtların PNG dosyaları silinir
- Kayıt klasörü ve dosya adı şablonu (`{yyyy}-{MM}-{dd}_{HH}{mm}{ss}`; geçersiz karakterler reddedilir)

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\gelismis-ekran-goruntusu-ve-not-alma-araci\EkranGoruntusu.exe` (.NET gerekmez) |
| Kaynaktan derle + başlat | `.\run.ps1` (`-Release`, `-NoBuild`) |
| Birim testleri | `.\run.ps1 -Check` |
| Arayüz testleri (FlaUI) | `.\run.ps1 -UiTest` (pencere açar, ekranı kopyalar) |
| Exe üret | `.\publish.ps1` → `dist\gelismis-ekran-goruntusu-ve-not-alma-araci\` |

Gereksinim (kaynaktan): Windows 10 (19041) veya 11, .NET 10 SDK. OCR için Windows'ta yüklü bir dil paketi.

## Kullanım

1. Kısayola basın (ya da **Yeni yakalama**), bölge seçin veya **Tam ekran**'ı seçip **Yakala** / `Enter`.
2. Düzenleyicide işaretleyin, hassas yerleri **Gizle** ile pikselleştirin, **Kaydet**. Görüntü geçmişe eklenir ve OCR metni aranabilir olur.
3. Geçmişte bir kayda **Düzenle** ile yeniden işaret ekleyebilirsiniz (yeni kayıt olarak kaydedilir).

| Kısayol | Eylem |
|---|---|
| `Ctrl+Alt+A` (ayarlanabilir, global) | Yakala |
| `Ctrl+N` / `Ctrl+O` / `Ctrl+,` | Yeni yakalama / Görsel aç / Ayarlar |
| `Ctrl+F`, `Esc` | Ara / aramayı temizle |
| `Enter`, `Delete` (geçmişte) | Düzenle / Sil |
| `Enter`, `Esc`, sağ tık (yakalamada) | Onayla / iptal |
| `1`–`5`, `Ctrl+Z`, `Ctrl+S`, `Ctrl+C`, `Esc` (düzenleyicide) | Araç / geri al / kaydet / kopyala / kapat |

## Veri ve gizlilik

- `%LOCALAPPDATA%\GelismisEkranGoruntusu\`: `screenshots.db` (SQLite geçmiş), `settings.json`, varsayılan `screenshots\` klasörü.
- `EKRAN_GORUNTUSU_DATA_DIR` ortam değişkeni veri klasörünü değiştirir (testler geçici klasör kullanır).
- Eski sürümlerin exe yanındaki `data\` geçmişi ilk açılışta kopyalanır.
- Ağ erişimi yok; OCR Windows'un yerleşik `Windows.Media.Ocr` motoruyla cihazda yapılır.

## Mimari / analiz

- **Yığın:** .NET 10 WPF (`net10.0-windows10.0.19041.0`), CommunityToolkit.Mvvm 8.4.2, NHotkey.Wpf 4.0.0,
  Microsoft.Data.Sqlite 10.0.12 + SQLitePCLRaw.bundle_e_sqlite3 3.0.5, System.Drawing (GDI ekran kopyası).
  Testler: xunit.v3 4.0.1 (Microsoft Testing Platform) + FlaUI.UIA3 5.0.0.
- **Klasörler:** `EkranGoruntusu/` (Views: Capture/Editor/Settings, ViewModels/MainViewModel, Services: Database,
  Settings, Ocr, ImageFile), `EkranGoruntusu.Tests/` (CoreTests, FeatureTests, UiTests), `assets/`.
- **Akış:** kısayol → ana pencere gizlenir → `CaptureWindow` sanal ekranı kopyalar → seçim → `EditorWindow`
  (InkCanvas üstünde şekiller; kayıtta `RenderTargetBitmap` tam çözünürlük) → PNG + OCR → SQLite → geçmiş.
- **Kararlar:** görseller belleğe kopyalanarak açılır (dosya kilidi yok); diyaloglar sahibine bağlı açılır;
  kısayol hazır seçeneklerden seçilir, kaydedilemezse eski kısayol korunur ve uyarı gösterilir.

## Testler

- **Birim (24):** `.\run.ps1 -Check` — geçmiş/sınır, ayarlar (kısayol, sınır, bozuk dosya), şablon, eski veri taşıma,
  pikselleştirme, görsel yükleme, OCR (dil paketi varsa), açılış duman testi.
- **Arayüz (2, FlaUI):** `.\run.ps1 -UiTest` — görsel aç → düzenleyici → araçlar → OCR → kaydet → geçmiş/detay → arama →
  düzenle → sil → Ayarlar (geçersiz şablon, sınır, kısayol, gözat, varsayılana dön) → geçmişi temizle; yakalama (tam ekran) →
  çizim/geri al/araç tuşları → kaydedilmemiş onayı → `Ctrl+S` → global kısayol → ana pencere kısayolları.
  Envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- OCR dil paketine bağlıdır; paket yoksa metin boş kalır.
- Yakalama GDI ile yapılır; korumalı (DRM) içerik siyah görünebilir.
- Şekiller kaydedildikten sonra düzenlenemez (görüntüye işlenir). Yol haritası: katmanlı proje dosyası, renk/kalınlık seçimi.
