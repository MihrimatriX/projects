# Canlı Duvar Kağıdı Motoru — Tasarım Sistemi

WinUI 3 masaüstü uygulaması için HTML prototip. Koyu tech/utility yüzey, tek yeşil accent, Segoe UI Variable tipografi.

## Dosya yapısı

```
docs/
├── index.html                    # Prototip launcher (ekran kartları)
├── canli-duvar-kagidi-prototip.html  # index.html yönlendirmesi
├── DESIGN-MANIFEST.json          # Makine okunur ekran/token haritası
├── DESIGN-HANDOFF.md             # Uygulama handoff sözleşmesi
├── css/
│   ├── tokens.css                # Renk, tipografi, spacing, motion
│   └── components.css            # WinUI shell, kartlar, form, tepsi
├── js/
│   ├── shell.js                  # Paylaşılan titlebar + sidebar
│   └── app.js                    # Prototip etkileşimleri
└── screens/
    ├── catalog.html              # Katalog grid + seçim paneli
    ├── player.html               # Aktif oynatıcı + WorkerW toggles
    ├── monitors.html             # Çoklu monitör ataması
    ├── settings.html             # Katalog URL, bellek, dayanıklılık
    └── tray.html                 # Sistem tepsisi bağlam menüsü
```

WinUI hedefi: `src/CanliDuvarKagidi.Shell/Themes/AppStyles.xaml` — yeşil token seti hizalandı (2026-06-09).

## Renk token'ları

| Token CSS | Kullanım |
|-----------|----------|
| `--bg` | Uygulama / sayfa arka planı |
| `--surface` | Titlebar, sidebar, kart |
| `--surface-2` | Hover, input, aktif sekme |
| `--fg` | Ana metin |
| `--muted` | İkincil metin, statusbar |
| `--border` | Ayırıcılar, win-shell çerçevesi |
| `--accent` | Birincil vurgu (oklch yeşil) |
| `--accent-dim` | Seçili nav, rozet arka plan |
| `--success` / `--warn` / `--danger` | Durum noktaları, tepsi çıkış |

## Bileşenler

- **`.win-shell`** — WinUI pencere mock (1280×800 max, gölge, radius)
- **`.titlebar` + `.win-controls`** — 48px başlık çubuğu
- **`.sidebar` + `.nav-item`** — Sol navigasyon (220px)
- **`.wallpaper-grid` + `.wp-card`** — Katalog grid, seçili durum
- **`.filter-tabs`** — Segmented filtre (Tümü / Video / Görsel / Web)
- **`.player-panel`** — Önizleme + yan panel (900px altında tek sütun)
- **`.monitor-row`** — Monitör atama satırı
- **`.tray-popup`** — Sistem tepsisi menüsü (ayrı yüzey)
- **`.statusbar`** — Alt durum çubuğu (28px, mono)

## Ekran eşlemesi

| HTML | WinUI / ürün |
|------|----------------|
| `screens/catalog.html` | Mağaza / katalog indirme akışı |
| `screens/player.html` | Teknik önizleme (debug; ana nav'da yok) |
| `screens/monitors.html` | Monitörler paneli |
| `screens/settings.html` | Ayarlar paneli |
| `screens/tray.html` | `TrayIconService` bağlam menüsü |

## Anti-pattern

- Mor/mavi gradient accent (`#5B6CFF`) — marka yeşil `oklch(58% 0.16 145)`
- Bej/krem arka plan yıkama
- Emoji ikon — SVG veya mono etiket
- Open Design / prototip etiketleri production UI'da

## Son güncelleme

2026-06-09 — Paylaşılan shell, responsive düzen, erişilebilirlik durumları, eksik buton etkileşimleri tamamlandı.
