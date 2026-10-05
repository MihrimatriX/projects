# Ekran Renk Seçici

Global kısayolla ekrandaki herhangi bir pikselin rengini büyüteçle yakalayıp panoya kopyalayan Windows tepsi uygulaması (WPF).

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Yakalama:** global kısayol (varsayılan `Ctrl+Shift+C`), tam ekran (çoklu monitör, DPI uyumlu) seçim katmanı, büyüteç, 1×1 / 3×3 / 5×5 piksel ortalama.
- **Formatlar:** HEX, RGB, HSL, OKLCH, CSS değişkeni; her biri tek tıkla kopyalanır.
- **Analiz:** WCAG kontrast oranı (beyaz / koyu / tamamlayıcı arka plan), tamamlayıcı ve analog palet, renk körlüğü simülasyonu (protan, deutan, tritan).
- **Giriş:** `#3B82F6`, `#38F` veya `rgb(59, 130, 246)` yazıp Enter — ekrandan seçmeden analiz.
- **Geçmiş:** son 10 renk (yeniden başlatmada korunur), geçmişi temizle.
- **Dışa aktarma:** Tailwind / Figma / CSS token.
- **Tepsi:** sol tık pencereyi açar; sağ tık menüsü (Ekrandan Seç, Pencereyi Göster, Ayarlar, Çıkış). Pencereyi kapatmak uygulamayı tepsiye gizler.

## Hızlı başlangıç

```powershell
..\dist\ekran-renk-secici\EkranRenkSecici.exe   # yayınlanmış tek exe (.NET gerekmez)
.\run.ps1             # Debug derler ve başlatır (-Release, -NoBuild)
.\run.ps1 -Check      # birim testleri + açılış duman testi (pencere açmaz)
.\run.ps1 -UiTest     # FlaUI arayüz testleri (pencere açar, panoyu sonra geri yükler)
.\publish.ps1         # self-contained tek exe -> ..\dist\ekran-renk-secici\
```

Exe üretme: `.\publish.ps1` → `dist\ekran-renk-secici\` (repo kökünde).

## Kullanım

Kısayola basın, imleci hedefe götürün, tıklayın veya Enter'a basın: renk seçili formatta panoya kopyalanır ve geçmişe eklenir.
Ana pencerede geçmişten bir renk seçerek ayrıntılarını (formatlar, kontrast, paletler) görün.

| Kısayol | Nerede | İşlev |
|---|---|---|
| Ctrl+Shift+C (ayarlanabilir) | Global | Seçim katmanını aç |
| Tık / Enter | Katman | Rengi kopyala ve kapat |
| Esc | Katman | İptal |
| Tab / Shift+Tab, ← → | Katman | Format değiştir |
| C | Katman | CSS formatı |
| Space | Katman | Büyüteç ızgarası |
| 1 / 3 / 5 | Katman | Örnekleme boyutu |
| Enter | Renk kodu kutusu | Girilen rengi analiz et |
| Enter / Esc | Ayarlar | Kaydet / İptal |

## Veri ve gizlilik

- Ayarlar `%AppData%\EkranRenkSecici\settings.json`, geçmiş `history.json`.
- `EKRAN_RENK_SECICI_DATA_DIR`: veri klasörünü değiştirir (testler gerçek ayar/geçmişe dokunmaz; tepsi ipucuna "(test)" eklenir).
- Ağ erişimi yok. Ekran görüntüsü yalnızca seçim katmanı açılırken bellekte alınır, diske yazılmaz.

## Mimari / analiz

- **Yığın:** .NET 10 WPF, CommunityToolkit.Mvvm 8.4.2, Hardcodet.NotifyIcon.Wpf 2.0.1, NHotkey.Wpf 4.0.0.
  Testler: xunit 2.9.3, FlaUI.UIA3 5.0.0.

```
EkranRenkSecici/
├── App.xaml(.cs)              # tema kaynakları, global hata yakalama, OnExplicitShutdown (tepsi)
├── MainWindow.xaml(.cs)       # tepsi simgesi, geçmiş, ayrıntı paneli
├── ViewModels/                # MainViewModel (kısayol kaydı, geçmiş, analiz), SettingsViewModel (çakışma denetimi)
├── Views/                     # SelectionWindow (katman + büyüteç), SettingsWindow, ExportWindow
├── Helpers/ColorHelper.cs     # dönüşümler (HSL, OKLCH), kontrast, paletler, renk körlüğü, dışa aktarma
├── Services/SettingsService.cs# settings.json + history.json
└── Models/                    # AppSettings, ColorItem
EkranRenkSecici.Tests/         # birim + duman (CoreTests), FlaUI (UiTests, UiSupport)
```

- **Veri akışı:** kısayol (NHotkey) → `SelectionWindow` ekranı göstermeden önce yakalar (karartma katmanı renge karışmaz)
  → fare konumu DIP → fiziksel piksel → ortalama renk → onayda panoya + `ColorSelected` → geçmiş + `history.json`.
- **Kararlar:** tek ekran kopyası üzerinden büyüteç (canlı yakalama yok, düşük CPU); katman açıkken kısayol ikinci
  katman açmaz; ayarlarda yeni kısayol deneme kaydıyla çakışma için sınanır.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim + açılış duman testi (dönüşümler, kontrast, ayrıştırma, ayarlar, geçmiş) | 25 | `.\run.ps1 -Check` |
| Arayüz (FlaUI: ana pencere, renk girişi, kopyalama, kontrast, paletler, dışa aktarma, ayarlar, seçim katmanı, global kısayol, tepsi) | 2 | `.\run.ps1 -UiTest` |

Envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Kısayol yalnızca Ctrl/Shift/Alt + A–Z; tüm değiştiriciler kapatılırsa Ctrl varsayılır.
- Büyüteç katman açıldığı andaki ekran kopyasını gösterir (video gibi değişen içerik güncellenmez).
- Win11 gizli simge taşmasında tepsi menüsü otomasyonla her zaman açılamaz.
- Yol haritası: açık tema, palet kaydetme / ASE dışa aktarma, geçmişi temizlemede geri al.
