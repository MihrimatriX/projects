# Pano Geçmişi Yöneticisi

Kopyaladığınız metin, bağlantı, kod, görsel ve dosya yollarını yerel SQLite'a kaydeden, global kısayolla açılan Windows (WPF) sistem tepsisi pano geçmişi aracı.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Yakalama:** panoyu otomatik dinler (metin, HTML, görsel, dosya listesi); aynı içerik tekrar kaydedilmez, en üste çıkar.
- **Bulma:** tam metin (FTS5) arama, Tümü / Metin / Görsel / Kod / URL filtreleri, sabitlenmiş öğeler en üstte.
- **Kullanma:** Enter/çift tık ile panoya al, isteğe bağlı otomatik Ctrl+V, sağ tık dönüşümleri (küçük harf, boşluk, JSON, Markdown link, satır sonları), görsellerde yerel Windows OCR.
- **Stack yapıştır:** seçili öğeleri kuyruğa al, global kısayolla sırayla yapıştır.
- **Silme ve geri al:** tekli/toplu silme, `Ctrl+Z` ile son silmeyi geri alma; "Geçmişi temizle" onay ister ve sabitlenenleri korur.
- **Gizlilik:** hassas uygulama listesi, regex filtresi, parola yöneticilerinin "kaydetme" işareti (`ExcludeClipboardContentFromMonitorProcessing`), hassas önizleme bulanıklaştırma, AES-256 şifreli mod + oturum kilidi.
- **Yedek:** JSON dışa/içe aktarma (görseller, sabitleme, zaman dahil).
- **Arayüz:** sistem tepsisi (sol tık panel, sağ tık menü), panel başlığında aynı menüyü açan ⋯ düğmesi, ilk açılış penceresi, yardım (F1).

## Hızlı başlangıç

```powershell
..\dist\clipboard-gecmisi-yoneticisi\ClipboardGecmisiYoneticisi.exe   # yayınlanmış tek exe (.NET gerekmez)
.\run.ps1             # Debug derler ve başlatır (-Release, -NoBuild)
.\run.ps1 -Check      # birim testleri + açılış duman testi (pencere açmaz)
.\run.ps1 -UiTest     # FlaUI arayüz testleri (pencere açar, panoyu sonra geri yükler)
.\publish.ps1         # self-contained tek exe -> ..\dist\clipboard-gecmisi-yoneticisi\
```

Exe üretme: `.\publish.ps1` → `dist\clipboard-gecmisi-yoneticisi\` (repo kökünde).
Diğer betikler: `.\install.ps1` / `.\uninstall.ps1` (yerel kurulum + kısayollar), `.\package-msix.ps1`
(publish çıktısından MSIX → `dist\ClipboardGecmisiYoneticisi.msix`, proje klasöründe; `-Sign` ile geliştirici sertifikası).

## Kullanım

Uygulama tepside çalışır. `Ctrl+Alt+V` paneli açar; yazmaya başlayıp ↓ ile listeye geçin, Enter ile öğeyi panoya alın.
Birden çok öğeyi Shift/Ctrl ile seçip "Stack'e ekle" deyin, sonra hedef uygulamada `Ctrl+Alt+Shift+V` ile sırayla yapıştırın.
Kısayollar Ayarlar'dan değiştirilebilir (iki kısayol aynı olamaz).

| Kısayol | İşlev |
|---|---|
| Ctrl+Alt+V (global) | Paneli aç |
| Ctrl+Alt+Shift+V (global) | Stack'ten sıradakini yapıştır |
| Enter / çift tık | Seçili öğeyi panoya al |
| ↓ (aramada) | Listeye geç |
| Shift+↑↓, Ctrl+tık, Ctrl+A | Çoklu seçim |
| Ctrl+F | Aramaya odaklan |
| Delete | Seçili öğe(ler)i sil |
| Ctrl+Z | Son silmeyi geri al |
| Ctrl+P | Sabitle / sabitlemeyi kaldır |
| F1 | Yardım |
| Esc | Paneli gizle |

## Veri ve gizlilik

- Veriler yalnızca yerelde: `%LocalAppData%\ClipboardGecmisiYoneticisi\` (`clipboard.db`, `images\`, `settings.json`, `logs\`, `encryption.meta`).
- `CLIPBOARD_GECMISI_DATA_DIR`: veri klasörünü değiştirir; bu durumda otomatik başlatma kaydına dokunulmaz ve tek-örnek kilidi klasöre özeldir.
- `CLIPBOARD_GECMISI_TEST=1` (yalnızca testler): yalnızca test işaretli pano içeriği kaydedilir, uygulamanın yazdıkları işaretlenir ve Windows pano geçmişine girmez; normal örnek test işaretli içeriği kaydetmez.
- Ağ: yalnızca Ayarlar'da güncelleme feed URL'si girilirse o adres okunur; varsayılan olarak ağ erişimi yok.

## Mimari / analiz

- **Yığın:** .NET 10 WPF, CommunityToolkit.Mvvm 8.4.2, Microsoft.Data.Sqlite 10.0.12 + SQLitePCLRaw.bundle_e_sqlite3 3.0.5,
  Hardcodet.NotifyIcon.Wpf 2.0.1, NHotkey.Wpf 4.0.0. Testler: xunit.v3 4.0.1 (Microsoft.Testing.Platform, `global.json`), FlaUI.UIA3 5.0.0.

```
ClipboardYoneticisi/
├── App.xaml(.cs)                 # tek örnek, global hata yakalama, tema kaynakları
├── MainWindow.xaml(.cs)          # panel, tepsi simgesi + ortak AppMenu, kısayollar, diyalog köprüleri
├── ViewModels/MainViewModel.cs   # geçmiş, filtre, seçim, stack, geri al, şifreleme akışı
├── Services/
│   ├── ClipboardMonitorService   # WM_CLIPBOARDUPDATE → kayıt; panoya tek DataObject ile yazma
│   ├── DatabaseService           # SQLite + FTS5, tekilleştirme, limit, otomatik silme
│   ├── EncryptionService         # AES-256 (PBKDF2), oturum kilidi
│   ├── ExportImportService       # JSON yedek
│   ├── SettingsService, AppPaths, StartupService, SingleInstanceService, UpdateCheckService, OcrService
├── Helpers/                      # sınıflandırma, dönüşümler, hassas içerik, kısayol ayrıştırma, Win32
└── *Window.xaml                  # Ayarlar, Kilit, Hoş geldiniz, Yardım, Hakkında, Güncelleme
ClipboardYoneticisi.Tests/        # birim + FlaUI UI testleri (UiSupport: uygulama başlatma, pano anlık görüntüsü, kilit)
macos/                            # SwiftUI menü çubuğu sürümü (MVP)
packaging/, releases/             # MSIX manifesti, sürüm bilgisi
```

- **Veri akışı:** pano değişince WM_CLIPBOARDUPDATE → filtreler (hassas uygulama, regex, dışlama işareti) →
  `DatabaseService.SaveItem` (aynı tür+içerik varsa zaman güncellenir) → `LoadHistory` (seçim korunur) → liste.
- **Kararlar:** OLE panosu tek kopyada iki güncelleme gönderir; görseller içerik özetiyle adlandırılır, metinler
  içerikle tekilleşir (şifreli modda çözülerek). Zaman damgası milisaniyeli (aynı saniyedeki kopyalar doğru sıralanır).
  Liste `SelectedItem` bağlaması tek yönlüdür; seçim VM'e `SelectionChanged` ile bildirilir. Tepsi ve ⋯ düğmesi aynı
  `ContextMenu` kaynağını kullanır.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim + açılış duman testi (veri, yedek, filtreler, dönüşümler, güncelleme, pano işaretleri) | 29 | `.\run.ps1 -Check` |
| Arayüz (FlaUI: panel, menü, tüm diyaloglar, şifreleme, ilk açılış, tepsi, klavye + global kısayollar) | 4 | `.\run.ps1 -UiTest` |

Envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Win11 gizli simge taşmasında tepsi sağ tık menüsü otomasyonla bazen açılamaz (test o adımı atlar; menü ⋯ ile test edilir).
- "Aç" dosya diyaloğunun onayı UIA ile güvenilir değil; içe aktarma akışı birim testiyle doğrulanır.
- Şifreli modda tekilleştirme kayıtları çözerek karşılaştırır (geçmiş limiti kadar, en fazla 5000).
- Pano geri yükleme okunabilen biçimlerle sınırlı (gecikmeli üretilen özel biçimler atlanabilir).
- Yalnızca koyu tema; açık tema ve gerçek zamanlı göreli zaman güncellemesi yol haritasında.
