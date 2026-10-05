# Canlı Duvar Kağıdı Motoru — plan

**Ürün modeli:** Yerel masaüstü uygulaması + self-host/bulut duvar kağıdı kataloğu (MVP tamamlandı)

## Özet teknoloji

| Alan | Değer |
|------|--------|
| Stack | C# · WinUI 3 · WebView2 · WorkerW enjeksiyonu |
| Ana rakipler / referans | Wallpaper Engine, Lively |
| Platform | Windows 10/11 |

## MVP sınırı (2026-05-30)

**Dahil:** statik görsel, video, web; çoklu monitör; JSON katalog; tepsi; fullscreen pause; explorer reconnect

**Hariç:** macOS/Linux, SaaS/faturalama, shader, workshop, Steam

## Kapsam fazları

| Faz | Durum | İçerik |
|-----|--------|--------|
| Keşif / POC | Tamam | WorkerW host + video/web oynatma |
| MVP | Tamam | Player katmanı, Shell, katalog, dayanıklılık |
| Sonraki | Backlog | Bulut CDN, hesap/favoriler, shader, workshop |

## Riskler

- WorkerW/Explorer API kırılganlığı → reconnect servisi (uygulandı)
- WebView2 bellek → monitör başına tek instance, pause (uygulandı)
- Katalog güvenliği → MVP'de güvenilen URL; imza sonraki faz

Detaylı uygulama planı: Cursor plan dosyası. Çalıştırma: [README.md](README.md)
