# Komut Paleti

Alt+Space ile açılan; uygulama, dosya/klasör yolu, PowerShell komutu ve web aramasını tek kutudan başlatan Windows komut paleti (WPF).

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Başlatma:** Başlat Menüsü kısayolları (.lnk/.url) SQLite'a indekslenir; en çok açılanlar üstte (`14×` rozeti).
  Her taramada kaldırılmış uygulamalar düşer, kullanım sayıları korunur; silinmiş kısayol başlatılırsa uyarı + listeden çıkarma.
- **Yollar:** `C:\Windows`, `%TEMP%`, `"D:\Belgeler\rapor.pdf"` gibi var olan yollar doğrudan açılır.
- **Komutlar:** `>` ile başlayan sorgu PowerShell'de çalışır (`> git status`); pencere çıktı için açık kalır.
- **Web:** yerel sonuç yoksa "Google'da ara".
- **Arka plan:** görev çubuğunda görünmez; tek örnek. Exe yeniden çalıştırılınca açık örneğin paleti görünür.
  Alt+Space başka bir uygulamada (ör. PowerToys Run) kayıtlıysa palet açılışta uyarıyla gösterilir.

## Hızlı başlangıç

```powershell
..\dist\evrensel-uygulama-ve-dosya-baslatici\KomutPaleti.exe   # yayınlanmış tek dosya exe
.\run.ps1             # Debug derler ve başlatır (-Release, -NoBuild)
.\run.ps1 -Check      # birim testleri + açılış duman testi (pencere açmaz)
.\run.ps1 -UiTest     # FlaUI arayüz testleri (geçici veri + sahte Başlat Menüsü, pencere açar)
.\publish.ps1         # self-contained tek exe -> dist\evrensel-uygulama-ve-dosya-baslatici\ (-Zip)
```

## Kullanım

Alt+Space (ya da exe'yi yeniden çalıştırmak) paleti açar; yazın, seçin, Enter. Palet odağı kaybedince gizlenir.

| Kısayol | İşlev |
|---|---|
| Alt+Space | Paleti aç / kapat |
| ↑ ↓ | Sonuçlar arasında gezin |
| Enter | Seçileni başlat (sonuç yoksa web araması) |
| Ctrl+Enter | Dosya konumunu Gezgin'de göster |
| Esc | Paleti gizle |
| Alt+F4 | Uygulamadan çık |

## Veri ve gizlilik

- Veritabanı: `%LOCALAPPDATA%\KomutPaleti\launcher.db` (eski sürümlerin exe yanındaki `data\launcher.db`'si ilk açılışta kopyalanır).
- Ortam değişkenleri: `KOMUT_PALETI_DATA_DIR` (veri klasörü; tek örnek kilidi de klasör başınadır),
  `KOMUT_PALETI_SCAN_DIR` (Başlat Menüsü yerine taranacak klasör — testler/demo için).
- Ağ erişimi yok; yalnızca "Google'da ara" varsayılan tarayıcıyı açar.

## Mimari / analiz

- **Yığın:** .NET 10, WPF, CommunityToolkit.Mvvm 8, Microsoft.Data.Sqlite 10.0.12, NHotkey.Wpf 4.
  Testler: xunit 2.9.3, FlaUI.UIA3 5.0.0.

```
UygulamaBaslatici/
├── App.xaml.cs                  # tek örnek (veri klasörü başına mutex) + "paleti göster" olayı
├── MainWindow.xaml(.cs)         # palet, global kısayol, klavye
├── ViewModels/MainViewModel.cs  # arama modları (uygulama / yol / komut / web), başlatma
├── Services/AppScannerService.cs# Başlat Menüsü tarayıcı (arka planda)
├── Services/DatabaseService.cs  # SQLite: eşitleme, arama, kullanım sayısı
└── Helpers/IconHelper.cs        # kısayol simgeleri
UygulamaBaslatici.Tests/         # birim + FlaUI testleri
```

- **Veri akışı:** açılışta tarama `Task.Run` ile SQLite'a yazılır; sorgu 100 ms gecikmeyle aranır ve gruplu listeye düşer.
- **Kararlar:** ikinci açılış adlandırılmış olay ile ilk örneğe "göster" der (uyarı kutusu yerine); kısayol kaydı
  başarısızsa engelleyen MessageBox yerine palet içinde uyarı. Ağ yolları (`\\sunucu`) her tuşta sorgu yapmasın diye çözülmez.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (veritabanı, yol çözme, PowerShell argümanları) + açılış duman testi | 14 | `.\run.ps1 -Check` |
| Arayüz (FlaUI: arama modları, boş durum, yeniden tarama, klavye ile başlatma, README görüntüsü) | 3 | `.\run.ps1 -UiTest` |

UI testleri sahte `.lnk` kısayollarıyla çalışır; başlatılan tek şey işaret dosyası yazan geçici bir `cmd` kısayoludur.

## Bilinen sınırlar ve yol haritası

- Alt+Space Windows/PowerToys Run ile çakışabilir; kısayol şimdilik değiştirilemez (yol haritası: ayarlanabilir kısayol).
- Bulanık (fuzzy) eşleşme yok; ad içinde alt dize araması yapılır.
- Klavye UI testi (gerçek tuş girdisi) paylaşılan masaüstünde odak alamayabildiği için elle doğrulanmalı.
