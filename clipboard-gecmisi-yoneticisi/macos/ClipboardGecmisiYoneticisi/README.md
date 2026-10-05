# Pano Geçmişi Yöneticisi — macOS

SwiftUI menü çubuğu uygulaması (MVP): `NSPasteboard`'u izler, metin ve dosya yollarını yerel SQLite'a kaydeder.

## Özellikler

- Metin / URL / dosya yolu yakalama, kategori etiketi (URL, e-posta, kod)
- Arama, sabitleme, silme, geçmişi temizleme
- Hariç tutulan uygulamalar (bundle ID), geçmiş limiti
- `⌘⇧V` global kısayolu uygulamayı öne getirir

## Çalıştırma

```bash
cd macos/ClipboardGecmisiYoneticisi
./build.sh
.build/release/ClipboardGecmisiYoneticisi
```

Test: `swift test`

## Gereksinimler

macOS 13+, Xcode 15+ / Swift 5.9+

Veriler: `~/Library/Application Support/ClipboardGecmisiYoneticisi/` (`clipboard.db`, `settings.json`)
