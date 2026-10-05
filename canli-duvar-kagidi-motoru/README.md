# Canlı Duvar Kağıdı Motoru

Windows 10/11 masaüstüne simgelerin arkasına görsel, video veya web (HTML/JS) duvar kağıdı yerleştiren WinUI 3 uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Duvar kağıtları**
- Görsel (png/jpg/bmp/gif), video (mp4/webm) ve web (HTML/CSS/JS) duvar kağıtları; video ve web WebView2 ile oynatılır
- Kendi dosyanızı ekleme: **Dosyadan ekle** (Ctrl+O) ya da kütüphaneye sürükle-bırak
- Kütüphanede arama: ad, açıklama ya da türe göre; Türkçe karaktersiz yazım da bulur ("gorsel" → "Görsel")
- Kaldırmadan önce onay (dosyalar diskten silinir)

**Monitörler ve oynatma**
- Her monitöre ayrı duvar kağıdı; atamalar kaydedilir ve açılışta geri yüklenir
- Tüm duvar kağıtlarını tek tuşla duraklatma (Ctrl+P, Monitörler sayfası ya da tepsi menüsü)
- Tam ekran (büyütülmüş) bir pencere öndeyken otomatik duraklatma
- Explorer yeniden başlarsa masaüstüne otomatik yeniden bağlanma

**Mağaza**
- Uygulamayla gelen yerel katalog ya da HTTP(S) üzerinden self-host JSON katalog
- İlk açılışta katalog otomatik yüklenir, kurulu olanlar "Kurulu" etiketiyle gösterilir

**Uygulama**
- Sistem tepsisi (Göster / Duraklat / Çıkış); pencereyi kapatmak tepsiye gizler
- Windows ile başlatma seçeneği, koyu tema, klavye kısayolları, ekran okuyucu adları
- Bozuk `settings.json` açılışı engellemez (`settings.json.bozuk` olarak kenara alınır); ayarlar atomik yazılır

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\canli-duvar-kagidi-motoru\CanliDuvarKagidi.exe` (repo kökünde, önce `.\publish.ps1`) |
| Kaynaktan çalıştır | `.\run.ps1` (x64 Debug, paketsiz, Windows App SDK gömülü) · `.\run.ps1 -Release` |
| Birim testleri + açılış duman testi | `.\run.ps1 -Check` |
| Arayüz testleri (pencere açar) | `.\run.ps1 -UiTest` |
| Exe üretme | `.\publish.ps1` → `dist\canli-duvar-kagidi-motoru\` (self-contained klasör, tek exe; hedefte .NET / Windows App Runtime gerekmez, yalnızca WebView2) |

Gereksinimler: Windows 10 1809+ / Windows 11, kaynaktan derlemek için .NET 10 SDK,
[WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (Windows 11'de hazır).
Geliştirici Modu gerekmez.

Eski release paketi (tek exe + taşınabilir zip, Inno Setup varsa kurulum exe'si): `.\build\publish.ps1`.
HTTP katalog denemek için: `.\catalog\serve.ps1` → Ayarlar'da `http://localhost:8080/index.json`.
Örnek paketleri yeniden üretmek: `.\catalog\pack-catalog.ps1` (başlık/açıklama her paketin `manifest.json`'ından okunur).

## Kullanım

1. İlk açılışta örnek duvar kağıtları **Kütüphanem**'e kurulur.
2. Bir kart seçip **Monitöre uygula** (ya da Enter / çift tık) → birincil monitöre uygulanır.
3. Farklı monitör için **Monitörler** → monitör ve duvar kağıdı seç → **Uygula**. **Kaldır** masaüstünü eski haline döndürür.
4. Yeni duvar kağıtları için **Mağaza** → kart seç → **İndir ve kur**.
5. **Ayarlar**: katalog adresi (`bundled`, `http(s)://…`, `file://` ya da tam dosya yolu), Windows ile başlat, tam ekranda duraklat → **Ayarları kaydet**.

| Kısayol | İşlev |
|---|---|
| Ctrl+1 / 2 / 3 / 4 | Kütüphanem / Mağaza / Monitörler / Ayarlar |
| Ctrl+F | Kütüphanede ara |
| Ctrl+O | Dosyadan ekle |
| Ctrl+P | Tüm duvar kağıtlarını duraklat / devam ettir |
| F5 | Yenile (Mağaza'da katalogu yeniden yükler) |
| Ctrl+S | Ayarları kaydet (Ayarlar sayfasında) |
| Enter / çift tık | Seçili kartı uygula (Mağaza'da: indir ve kur) |
| Delete | Seçili kartı kaldır (onay sorar) |

## Veri ve gizlilik

- Veriler: `%AppData%\CanliDuvarKagidi\` → `installed\` (kurulu paketler), `cache\` (indirme önbelleği), `settings.json`.
- `CANLI_DUVAR_DATA` ortam değişkeni bu klasörü değiştirir (testler geçici klasör kullanır).
- `CANLI_DUVAR_UITEST=1`: arayüz testi kipi — duvar kağıdı masaüstüne gömülmez, kayıt defterine yazılmaz.
- "Windows başlangıcında çalıştır" yalnızca `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\CanliDuvarKagidi` değerini yazar/siler.
- Ağ erişimi yalnızca Ayarlar'da HTTP(S) katalog adresi girildiğinde yapılır (katalog + paket indirme). Varsayılan `bundled` katalog tamamen yereldir; telemetri yoktur.
- Web duvar kağıtları WebView2'de çalışan HTML/JS'tir; yalnızca güvendiğiniz kataloglardan kurun.

## Mimari / analiz

**Yığın:** .NET 10 · WinUI 3 / Windows App SDK 2.5.1 (paketsiz, self-contained) · Windows SDK BuildTools 10.0.28000 ·
WinForms barındırma pencereleri + Microsoft.Web.WebView2 1.0.4258 · System.Text.Json · testler: xunit v3 4.0 (Microsoft Testing Platform), FlaUI.UIA3 5.0.

```
src/CanliDuvarKagidi.Core/      Motor, WorkerW gömme, katalog, kurulum, ayarlar (UI'dan bağımsız)
  Host/                         DesktopWallpaperHost (WorkerW'a gömülü pencere), NoDesktopHost (test kipi)
  Services/                     WallpaperEngineService, CatalogService, InstalledWallpaperService, SettingsService, …
src/CanliDuvarKagidi.Players/   ImagePlayer (PictureBox), VideoPlayer / WebPlayer (WebView2), ayrı STA UI iş parçacığı
src/CanliDuvarKagidi.Shell/     WinUI 3 arayüz (MainPage), tepsi simgesi, başlangıç kaydı
tests/CanliDuvarKagidi.Core.Tests/  Birim testleri
tests/CanliDuvarKagidi.UiTests/     FlaUI arayüz testleri
catalog/                        Örnek katalog (index.json + zip paketler), paketleme ve HTTP sunucu betikleri
tools/DesktopSmoke/             Gerçek masaüstüne 8 sn örnek görsel gömen elle duman aracı
build/, installer/              Eski release betiği ve Inno Setup dosyası
```

**Veri akışı:** Arayüz → `WallpaperEngineService.ApplyWallpaperAsync(monitör, id)` → manifest `InstalledWallpaperService`'ten okunur →
host fabrikası bir `IWallpaperHost` oluşturur (gerçekte Progman'a `0x052C` gönderilip WorkerW/SHELLDLL_DefView arkasına
çocuk pencere gömülür) → `WallpaperPlayerFactory` türe göre oynatıcıyı host penceresine bağlar → atama `settings.json`'a yazılır →
`SessionsChanged` arayüzü yeniler. Bir zamanlayıcı her saniye tam ekran durumunu kontrol eder; kullanıcı duraklatması ile
tam ekran duraklatması birlikte değerlendirilir. `ExplorerReconnectService` Explorer yeniden başlarsa tüm oturumları yeniden kurar.

**Tasarım kararları**
- Paketsiz + `WindowsAppSDKSelfContained`: Geliştirici Modu ve ayrı runtime kurulumu gerekmez; bedeli tek exe yerine ~316 MB klasör.
- Oynatıcılar WinUI yerine WinForms/WebView2 pencereleri: WorkerW'a `SetParent` ile gömülebilen klasik HWND gerekir.
- Host fabrikası enjekte edilebilir: arayüz testleri gerçek masaüstünü değiştirmeden "uygula" akışının tamamını çalıştırır.
- Katalog paket kimlikleri tek klasör adına sınırlanır (`..\` ile `installed\` dışına taşma engellenir).

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (xunit v3) | 48 | `.\run.ps1 -Check` (ardından 10 sn açılış duman testi) |
| Arayüz (FlaUI UIA3) | 7 + 1 ekran görüntüsü | `.\run.ps1 -UiTest` |

Arayüz testleri tüm sayfaları, düğmeleri, onay iletişim kutusunu, gerçek Windows dosya seçicisini ve klavye kısayollarını
UIA desenleriyle sürer; ayrıntılı envanter: [docs/arayuz-testi.md](docs/arayuz-testi.md). Yayınlanmış exe'ye karşı çalıştırmak için
`CDK_UITEST_EXE` ortam değişkenine exe yolunu verin. README görüntülerini yenilemek: `CDK_EKRAN_DIR=<docs yolu>` ile
`Screenshot_for_readme` testini çalıştırın (PrintWindow, 1280×800).

## Bilinen sınırlar ve yol haritası

- Kartlarda manifestteki `thumbnail` henüz gösterilmiyor (tür simgesi kullanılıyor).
- Görsel duvar kağıdı ekrana sığdırma modu sabit (uzat); kırp/ortala seçeneği yok.
- Duraklatma video ve web için etkili; durağan görselde fark yaratmaz.
- Katalog paketleri imzalanmıyor; HTTP katalog yalnızca güvenilir kaynaklardan kullanılmalı.
- Sürükle-bırak ve tepsi menüsü UIA ile otomatik test edilemiyor (aynı içe aktarma/duraklatma mantığı birim testli).
- `Players` projesinde WebView2 paketinin WPF derlemesi kaynaklı zararsız `MSB3277` (WindowsBase) uyarısı var.
- Yol haritası: küçük resimler, oynatma listesi / zamanlayıcıyla değişen duvar kağıdı, monitör başına sığdırma modu, pil tasarrufu kipinde duraklatma.
