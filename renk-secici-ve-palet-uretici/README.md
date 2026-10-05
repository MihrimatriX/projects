# Renk Seçici ve Palet Üretici

Harmonik 5 renkli palet üretir, WCAG kontrastını gösterir ve CSS/SCSS/Tailwind/JSON olarak dışa aktarır (Flutter; Windows, web ve mobil).

![Ekran görüntüsü](docs/ekran.png)

> Ekran görüntüsü web derlemesidir; palet rastgele üretildiği için her açılışta renkler farklıdır.

## Özellikler

- Tamamlayıcı, analog ve üçlü (triadic) palet modları; kilitli renkler korunur
- Her renkte WCAG kontrast rozeti (AAA / AA / Düşük / Başarısız); oran, arayüzün arka plan rengine göre hesaplanır
- Dışa aktarma: CSS `:root`, SCSS değişkenleri, Tailwind `colors` veya JSON (hex + rgb + hsl token'ları; panoya kopyala)
- HEX ile renk düzenleme (`E` ya da seçili renge tekrar tıkla): `#38F` / `3388ff` gibi girdiler kabul edilir, geçersiz girdi uyarı verir; elle girilen renk kilitlenir
- Görselden palet + arayüz teması çıkarma (dosya, kamera, ekran görüntüsü)
- Son 20 palet geçmişi (cihazda saklanır; bozuk kayıtlar atlanır)
- Kontrast oranı aşağı yuvarlanarak gösterilir (4.47:1 "4.5" görünüp AA sanılmaz)
- Dar pencerede (< 600 px) mobil yerleşim

## Hızlı başlangıç

Gereksinimler: Flutter SDK (Dart ≥ 3.2); Windows masaüstü için Visual Studio "Desktop development with C++" ve Windows Geliştirici Modu.

```powershell
.\run.ps1          # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome   # cihazı elle seç (windows, chrome, edge veya flutter devices id'si)
.\run.ps1 -Check   # sadece flutter analyze + flutter test
.\publish.ps1      # Windows exe: <repo>\dist\renk-secici-ve-palet-uretici\ altına
```

Elle: `flutter pub get` ve `flutter run -d windows`.

**Windows exe için Geliştirici Modu gerekir** (Flutter eklentileri sembolik bağlantı ister): `start ms-settings:developers` ile açın, ardından `.\publish.ps1` çalıştırın; kapalıyken betik Türkçe hata ile durur. Geliştirici Modu kapalıysa web hedefi (`.\run.ps1 chrome`) kullanılabilir.

## Kullanım

Üstteki seçiciyle mod (Tamamlayıcı / Analog / Üçlü) seçilir; "Yeni palet" kilitsiz renkleri yeniden üretir. Bir rengi `L` ile (ya da üzerindeki kilit simgesiyle) sabitleyebilir, seçili renge tekrar tıklayarak HEX'ini düzenleyebilirsiniz. "Dışa aktar" (veya `C` / `T`) CSS/SCSS/Tailwind/JSON çıktısını gösterir; kamera simgesi görselden palet/tema çıkarır; saat simgesi son 20 paleti açar.

| Kısayol | İşlem |
|---|---|
| `Boşluk` | Yeni palet (kilitsiz renkler) |
| `L` | Seçili rengi kilitle / aç |
| `Enter` | Seçili rengin HEX'ini panoya kopyala |
| `1` – `5` | Renk seç |
| `E` | HEX düzenle |
| `C` / `T` | CSS / Tailwind dışa aktar |
| `H` | Geçmiş |
| `I` | Görselden tema/palet |
| `?` | Kısayol yardımı |
| `Esc` | Kapat |

## Veri ve gizlilik

- Tek kalıcı veri palet geçmişidir: `shared_preferences` içinde `palet:history` anahtarı (son 20 palet, hex + tarih). Windows'ta kullanıcı uygulama verisi klasöründeki `shared_preferences.json`, web'de tarayıcı `localStorage`. Konumu değiştiren bir ortam değişkeni yoktur.
- Ağ erişimi yoktur: paletler, kontrast ve görsel analizi cihazda hesaplanır. Seçtiğiniz görsel/ekran yakalama sadece bellekte işlenir, kaydedilmez.
- Kamera ve ekran yakalama yalnızca siz istediğinizde, işletim sistemi/tarayıcı izniyle çalışır.

## Mimari / analiz

Teknoloji (pubspec.yaml, sürüm 1.0.0+1): Flutter (Dart ≥ 3.2), shared_preferences ^2.2.3, file_picker ^8.1.2, image_picker ^1.1.2, screen_capturer ^0.2.3, image ^4.2.0, web ^1.1.1; ek bağımlılık (state management vb.) yok, durum `StatefulWidget` içinde tutulur.

```
lib/main.dart                      giriş noktası → PaletteApp (app.dart)
lib/core/theme/app_theme.dart      renk/yarıçap/tipografi token'ları, koyu tema
lib/domain/palette_core.dart       saf mantık: HEX/RGB/HSL dönüşümü, WCAG kontrast, harmonik palet
                                   üretimi, CSS/SCSS/Tailwind/JSON dışa aktarma, k-means ile görselden palet/tema
lib/data/palette_history_repository.dart   son 20 palet (SharedPreferences, bozuk kayıt toleranslı)
lib/services/                      görsel seçme (dosya/kamera/ekran) ve ekran yakalama
                                   (screen_capture_io / _web / _stub: platforma göre koşullu içe aktarma)
lib/presentation/palette_screen.dart   tek ekran: masaüstü ve mobil gövde, dışa aktarma, geçmiş, görsel çıkarma sayfası
lib/presentation/widgets/          logo, arka plan, ortak bileşenler
```

Veri akışı: mod + kilitler → `PaletteCore.regenerateUnlocked` (rastgele taban ton, moda göre sabit renk çarkı açıları, HSL→HEX) → `PaletteSlot` listesi → ekran; her yeni palet `PaletteHistoryRepository.add` ile geçmişe yazılır. Görselden çıkarma: görsel küçültülür (≤140 px), piksel örneklenir, RGB uzayında k-means (12 tur) ile 5 renk, ayrıca arayüz teması (arka plan/panel/vurgu/metin) türetilir.

Tasarım kararları: tüm renk/kontrast/dışa aktarma mantığı Flutter'dan bağımsız `PaletteCore` içindedir (birim testlenir); kontrast rozeti aşağı yuvarlar; elle girilen HEX kilitlenir; geçmişte aynı palet art arda tekrarlanmaz.

## Testler

`flutter test` veya `.\run.ps1 -Check` (analiz + test): `palette_core_test` (13), `history_and_edit_test` (5), `widget_test` (2) — toplam 20 test çağrısı.

## Bilinen sınırlar

- Palet her seferinde rastgele taban tondan üretilir; aynı palet tekrarlanamaz (geçmişten açılır).
- Kontrast yalnızca arayüz arka plan rengine göre gösterilir; iki seçili renk arasında karşılaştırma yoktur.
- Mobilde ekran yakalama API'si yoktur; "ekran" kaynağı galeriden kayıtlı ekran görüntüsü seçtirir.
- Windows exe'si Geliştirici Modu açık olmadan derlenemez; bu ortamda exe doğrulanmadı.
