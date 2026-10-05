# Hızlı Dosya Arama

`Alt+F` ile açılan, dosya adlarını yerel SQLite indeksinde yazdıkça arayıp Enter ile açan klavye odaklı Windows (WPF) aracı.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Arama:** yazdıkça (dosya adında, en fazla 50 sonuç); çok kelime sırasız eşleşir (`rapor 2024`);
  nokta ile başlayan kelime uzantı süzgecidir (`rapor .pdf`, `butce .xlsx .csv`).
- **Eylemler:** `Enter` aç, `Ctrl+Enter` Gezgin'de göster, `Shift+Enter` yolu kopyala.
- **Son dosyalar:** boş aramada son açılanlar; silinmiş/taşınmış dosya açılmak istenirse bildirilir ve indeksten çıkarılır.
- **Alias'lar:** `aliases.json` içindeki hazır sorgular palette çip olarak görünür.
- **İndeks:** Belgeler, Masaüstü, İndirilenler ve varsa `Desktop\DEV\projects`; ilk açılışta indeks boşsa tarama otomatik.
- **Arka plan:** sistem tepsisi (Aç / Yeniden indeksle / Çıkış), tek örnek — exe'yi yeniden çalıştırmak paleti öne getirir.

## Hızlı başlangıç

```powershell
..\dist\hizli-dosya-arama-ve-acma-araci\HizliDosyaArama.exe   # yayınlanmış tek dosya exe
.\run.ps1            # Debug derle + başlat (-Release, -NoBuild)
.\run.ps1 -Check     # birim testleri + açılış duman testi (geçici klasörlerde)
.\publish.ps1        # self-contained tek exe -> dist\hizli-dosya-arama-ve-acma-araci\
```

## Kullanım

| Kısayol | İşlev |
|---|---|
| Alt+F | Paleti aç |
| ↑ ↓ | Sonuçlar arasında gezin |
| Enter | Dosyayı aç |
| Ctrl+Enter | Gezgin'de göster |
| Shift+Enter | Yolu kopyala |
| Esc | Kapat (uygulama tepside kalır) |

## Veri ve gizlilik

- Veritabanı, `aliases.json` ve `crash.log`: `%LOCALAPPDATA%\HizliDosyaArama\` (eski sürümlerin exe yanındaki `data\`
  klasörü ilk açılışta buraya kopyalanır). `HIZLI_DOSYA_ARAMA_DATA_DIR` ortam değişkeniyle değiştirilebilir.
- Yalnızca dosya adı, yol, boyut ve tarih indekslenir; içerik okunmaz. Ağ erişimi yok.

## Mimari / analiz

- **Yığın:** .NET 10, WPF (+ WinForms `NotifyIcon` tepsi), CommunityToolkit.Mvvm 8, Microsoft.Data.Sqlite 10.0.12,
  NHotkey.Wpf 4. Testler: xunit 2.9.3.

```
HizliDosyaArama/
├── App.xaml.cs                    # tek örnek (mutex + "paleti göster" olayı), çökme günlüğü
├── MainWindow.xaml(.cs)           # tam ekran karartma + ortadaki palet, tepsi menüsü
├── ViewModels/MainViewModel.cs    # arama, son dosyalar, alias'lar, Alt+F kaydı
├── Services/IndexerService.cs     # klasör tarama (arka planda, toplu ekleme)
├── Services/DatabaseService.cs    # SQLite: dosyalar, son açılanlar, sorgu ayrıştırma
└── Helpers/FileHelper.cs          # açma / Gezgin / panoya kopyalama
HizliDosyaArama.Tests/             # xunit testleri
```

- **Veri akışı:** indeksleyici `Task.Run` ile klasörleri gezip 1000'lik gruplarla SQLite'a yazar; her tuş vuruşu
  terimler + uzantılar olarak ayrıştırılıp tek sorguyla aranır.
- **Kararlar:** Alt+F başka uygulamada kayıtlıysa sessizce atlanır (tepsi menüsü çalışır); ikinci örnek
  `Environment.Exit` ile hemen kapanır (WPF `Shutdown` ~10 sn bekletiyordu).

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (sorgu ayrıştırma, arama, son dosyalar, indeksleyici, veri klasörü) + açılış duman testi | 13 | `.\run.ps1 -Check` |

Otomatik arayüz testi yok; arayüz elle test edilir.

## Bilinen sınırlar ve yol haritası

- Tek örnek kilidi genel: farklı veri klasörüyle ikinci bir örnek çalıştırılamaz.
- İndeks canlı izlenmez (FileSystemWatcher yok); yeni dosyalar için tepsiden "Yeniden indeksle".
- Yol haritası: ayarlanabilir klasörler ve kısayol, içerik araması, FlaUI arayüz testleri.
