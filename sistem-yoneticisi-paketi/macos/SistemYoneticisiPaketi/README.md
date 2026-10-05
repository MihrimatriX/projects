# Sistem Yöneticisi Paketi — macOS

SwiftUI tabanlı basit macOS sistem monitörü.

- CPU, RAM ve disk kullanımı (2 sn'de bir yenilenir)
- Çalışan uygulamalar listesi
- Oturum açılışında başlatma (SMAppService; imzasız derlemelerde çalışmayabilir)

## Derleme ve çalıştırma

```bash
./build.sh
.build/release/SistemYoneticisiPaketi
swift test   # testler
```

Gereksinim: macOS 13+, Swift 5.9+ (Xcode 15+).
