# Markdown Not Defteri

Yerel `.md` dosyaları ve hızlı notlar için canlı önizlemeli markdown editörü.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Bölünmüş / Düzenle / Önizle modları (dar ekranda otomatik Düzenle)
- Araç çubuğu: kalın, italik, kod, H1, link
- `.md` dosyası aç; değişiklikler 2 sn sonra otomatik diske yazılır (hızlı notlar da otomatik kaydedilir). Geri dönerken / pencere kapanırken bekleyen değişiklik hemen yazılır; kayıt başarısızsa çıkmadan önce sorulur. UTF-8 olmayan dosyalar bozulmasın diye açılmaz.
- Son açılan 10 dosya ana sayfada
- Hızlı notlar: cihazda (SharedPreferences) saklanır; Türkçe harf duyarsız arama (başlık + içerik), silmeyi `Geri al`
- Dışa aktar: Markdown (.md) veya tek başına açılan HTML (.html, tablo/görev listesi dahil); web'de panoya kopyalar
- Önizleme: YAML ön bilgisi gizlenir, dosyanın yanındaki göreli görseller (`![](resim.png)`) gösterilir; başlık, liste, görev listesi, tablo, alıntı ve kod blokları çizilir
- Kelime sayısı, okuma süresi, satır numarası ve kayıt durumu (alt çubuk)
- Sepia / Koyu / Sistem tema (varsayılan Sepia)

## Hızlı başlangıç

```powershell
.\run.ps1          # Windows > Chrome > Edge sırasıyla ilk uygun cihaz
.\run.ps1 chrome   # cihazı elle seç
.\run.ps1 -Check   # sadece flutter analyze + flutter test
.\publish.ps1      # Windows exe -> dist\markdown-not-defteri\markdown_not_defteri.exe
```

Windows exe üretmek (`.\publish.ps1`) ve Windows masaüstü hedefiyle çalıştırmak için Windows Geliştirici Modu açık olmalıdır (Flutter eklentileri symlink ister): `start ms-settings:developers`. Mod kapalıyken `run.ps1` Chrome/Edge'e düşer; `publish.ps1` net bir mesajla durur.

Elle: `flutter pub get` ve `flutter run -d windows` (veya `-d chrome`)

Gereksinimler: Flutter SDK (Dart ≥ 3.2); Windows masaüstü için Visual Studio "Desktop development with C++". Dosya açma/kaydetme yalnızca masaüstü/mobilde çalışır; web'de (Chrome) `Dosya aç` içeriği hızlı not olarak içe aktarır.

## Kullanım

Üst gezinme: **Ana Sayfa** (hoş geldiniz, son dosyalar, hızlı notlar), **Notlar** (tüm hızlı notlar ve arama), **Editör**, **Ayarlar** (tema). Ana sayfadan "Yeni not" ile hızlı not başlatılır, "Dosya aç…" ile bir `.md` dosyası seçilir.

| Kısayol | İşlev |
|---------|-------|
| `Ctrl+S` | Kaydet |
| `Ctrl+B` | Seçimi kalın yap |
| `Ctrl+I` | Seçimi italik yap |

## Veri ve gizlilik

- Hızlı notlar ve son açılan dosya listesi `SharedPreferences` içinde JSON olarak saklanır (`notes_v1`, `recent_md_files_v1`); tema tercihi `theme_pref_v1` anahtarındadır. Windows'ta kullanıcının AppData klasöründe, web'de tarayıcı `localStorage`'ındadır. Veri klasörünü değiştiren bir ortam değişkeni yoktur.
- Açılan `.md` dosyaları olduğu yerde kalır; uygulama yalnızca değişiklikleri aynı dosyaya yazar. Dışa aktarma kullanıcının seçtiği konuma yapılır.
- Uygulama ağ erişimi yapmaz; hesap/telemetri yoktur.

## Mimari / analiz

Teknoloji (pubspec / pubspec.lock): Flutter 3.x (SDK `>=3.2.0 <4.0.0`), `flutter_riverpod` 2.6.1, `go_router` 18.0.2, `shared_preferences` 2.5.5, `flutter_markdown` 0.7.7+1 + `markdown` 7.3.1 (önizleme ve HTML üretimi), `file_picker` 8.3.7. Sürüm: 1.0.0+1.

```
lib/main.dart, lib/app.dart   ProviderScope, go_router (/, /notes, /notes/edit, /settings), tema
lib/core/                     tema (Sepia/Koyu), markdown stilleri, biçim yardımcıları, üst gezinme (AppShell)
lib/features/home/            ana sayfa (son dosyalar, hızlı notlar)
lib/features/notes/           editör ekranı, not listesi, not modeli, depolar (notes_v1, recent_md_files_v1),
                              markdown_files.dart (dosya aç/kaydet, HTML dışa aktarma)
lib/features/settings/        tema seçimi
scripts/generate-assets.ps1   ikonları üretir
```

Veri akışı: editör ekranı bir hızlı notu (`Note`) ya da diskteki bir dosyayı (`EditorArgs`) açar; metin değiştikçe 2 saniyelik bir zamanlayıcı kaydı tetikler (hızlı not → `NotesRepository`, dosya → doğrudan diske). Önizleme `flutter_markdown` ile çizilir; HTML dışa aktarma `markdown` paketiyle tek dosyalık belge üretir.

Tasarım kararları:
- Router bir kez kurulur; tema değişince kullanıcı ana sayfaya atılmaz.
- UTF-8 olmayan dosyalar açılmaz, aksi halde otomatik kayıt dosyayı kalıcı bozardı.
- Kayıt başarısızsa çıkışta kullanıcıya sorulur; bekleyen değişiklik geri dönerken/pencere kapanırken hemen yazılır.

## Testler

`test/` altında 2 dosya, 12 test: `notes_test.dart` (11) ve `widget_test.dart` (1). Çalıştırma: `.\run.ps1 -Check` (analiz + test) veya `flutter test`.

## Bilinen sınırlar

- Windows exe için Geliştirici Modu gerekir (yukarıya bakın); yoksa uygulama web (Chrome/Edge) ile çalıştırılabilir.
- Web'de dosya açma/kaydetme yoktur: `Dosya aç` içeriği hızlı not olarak alır, dışa aktarma panoya kopyalar.
- Araç çubuğunda tablo, liste veya görsel ekleme düğmesi yoktur (yalnızca kalın, italik, kod, H1, link).
- Ayarlar'daki "Editör font boyutu" (Faz 2) ve "Otomatik kaydetme" satırları yalnızca bilgi gösterir; değiştirilemez (font 16 px, otomatik kayıt 2 sn sabit).
- Çok sekmeli/çok dosyalı çalışma alanı yoktur; bir seferde tek belge düzenlenir.
