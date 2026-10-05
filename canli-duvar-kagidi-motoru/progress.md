# Canlı Duvar Kağıdı Motoru — ilerleme günlüğü

| Tarih | Durum | Not |
|--------|--------|-----|
| 2026-05-02 | Kayıt | Planlama üçlüsü oluşturuldu. |
| 2026-05-30 | MVP | C# solution: Core, Players, Shell (WinUI 3). WorkerW host, çoklu monitör, katalog, tepsi, dayanıklılık. |
| 2026-05-30 | UI | Modern WinUI 3 arayüz, kart tabanlı kütüphane/mağaza, InfoBar geri bildirimleri. |
| 2026-05-30 | Paket | Self-contained tek exe (`dist/app/CanliDuvarKagidi.exe`), bundled katalog, portable zip. |
| 2026-10-05 | Kalite | Bozuk ayar dosyasi toleransi + atomik kayit, indirilen zip temizligi, birincil monitor duzeltmesi, olay isleyicilerinde hata yakalama; yerel gorsel/video ice aktarma (dosya secici + surukle-birak); xunit testleri (26) + `run.ps1 -Check` duman testi; kok `publish.ps1` -> `dist\canli-duvar-kagidi-motoru\`. |

## Tamamlanan milestone'lar

- Faz 0–3: MVP tamamlandı
- Release: `build/publish.ps1` → `dist/app/CanliDuvarKagidi.exe` + `dist/CanliDuvarKagidi-Portable-x64.zip`
- İlk çalıştırma: bundled örnek duvar kağıtları otomatik kurulur
