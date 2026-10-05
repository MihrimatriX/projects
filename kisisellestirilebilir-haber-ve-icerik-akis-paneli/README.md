# Kişiselleştirilebilir Haber ve İçerik Akış Paneli

RSS/Atom akışlarını yerel SQLite'ta toplayan, kendi bilgisayarınızda çalışan üç sütunlu haber okuyucu.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Okuma**
- Üç sütun: feed listesi, makale listesi, okuyucu (mobilde sekmeler)
- Okunmamış / Yıldızlı / Tümü filtreleri, okundu ve yıldız işaretleme, tümünü okundu işaretle
- Başlık ve özet içinde Türkçe harf duyarsız arama
- Makale HTML'i DOMPurify ile temizlenir (betik, olay öznitelikleri çalışmaz)

**Abonelikler**
- RSS/Atom ekleme, klasörleme, OPML içe/dışa aktarma (iç içe klasörler dahil)
- Arka planda otomatik senkron: 5 / 15 / 30 / 60 dk (`/settings`)
- Hatalı/çevrimdışı feed: 15 sn zaman aşımı, makaleler korunur, hata feed'in yanında (`!`) ve ayarlarda gösterilir
- Varsayılan feed'ler yalnızca ilk açılışta bir kez eklenir (silinirse geri gelmez)
- Yerel/özel ağ adreslerine istek engellenir (SSRF koruması; yönlendirme ve DNS sonucu da denetlenir)

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\kisisellestirilebilir-haber-ve-icerik-akis-paneli\HaberAkisPaneli.exe` (Node gerekmez) |
| Kaynaktan çalıştır | `.\run.ps1` → http://localhost:3104 |
| Testler | `.\run.ps1 -Check` (vitest + tsc + Playwright e2e; internet gerekmez) |
| Exe üret | `.\publish.ps1` → `dist\kisisellestirilebilir-haber-ve-icerik-akis-paneli\` |

Elle: `npm install`, `npx prisma db push`, `npm run dev`. Üretim: `npm run build` + `npm start`.
Gereksinim (kaynaktan): Node.js 22.5+.

## Kullanım

1. İlk açılışta iki varsayılan feed (Anadolu Ajansı, DEV Community) eklenir; **+ RSS ekle** ile kendi feed'inizi
   ekleyin ya da **OPML içe aktar** ile başka okuyucudan taşıyın.
2. Soldan feed/klasör seçin, ortada makaleye tıklayın; sağda okuyun, **Orijinal** ile kaynağı açın.
3. Yenileme sıklığını ve feed hatalarını **Ayarlar** (`/settings`) ekranında yönetin.

| Kısayol | İşlev |
|---|---|
| J / K | Sonraki / önceki makale |
| M | Okundu / okunmadı |
| S | Yıldızla |
| O | Orijinali aç |
| R | Feed'leri yenile |
| / | Aramaya odaklan (Esc temizler) |
| ? | Kısayol çubuğunu göster/gizle |
| Esc | Pencereyi kapat; mobilde listeye dön |

## Veri ve gizlilik

- Veriler yerel SQLite'ta: kaynaktan `prisma\dev.db`, exe'de `%APPDATA%\Haber Akis Paneli\haber.db`
  (ilk açılışta boş şablondan kopyalanır, mevcut veri ezilmez).
- Ağ erişimi: yalnızca abone olunan feed adreslerine (ve "Orijinal" bağlantısı tarayıcıda). Telemetri yok.
- Ortam değişkenleri: `DATABASE_URL` (veritabanı dosyası), `APP_DATA_DIR` (exe veri klasörü),
  `DEFAULT_FEEDS` (JSON, ilk feed'ler) ve `RSS_ALLOW_PRIVATE_HOSTS=1` — son ikisi yalnızca testler içindir.

## Mimari / analiz

| Katman | Teknoloji |
|---|---|
| UI | Next.js 16.3 (App Router, server actions), React 19.3, Tailwind CSS 4.3, Zustand 5 |
| Veri | Prisma 6.19 + SQLite (`Feed`, `Article`, `AppSetting`) |
| Feed | rss-parser 3, DOMPurify 3, kendi SSRF denetimi (`src/lib/ssrf.ts`) |
| Masaüstü | Electron 42 kabuğu (`desktop/main.cjs`) + Next standalone sunucu, electron-builder |
| Test | Vitest 3, Playwright 1.63 (web + `_electron`), TypeScript 6 |

```
prisma/          SQLite şeması
src/app/         sayfalar (/, /settings) ve server action'lar (actions.ts)
src/components/  Sidebar, ArticleList, ArticleReader, FeedModal, KeyboardManager
src/lib/         zustand store, feed indirme, SSRF kontrolü, feed öğesi/OPML dönüşümü, biçimlendirme
scripts/         create-db.mjs (şemadan boş SQLite), generate-assets.mjs (ikonlar)
desktop/         Electron kabuğu (standalone server.js'i ELECTRON_RUN_AS_NODE alt süreciyle başlatır)
tests/           vitest, fixtures/ (yerel RSS/Atom + sunucu), e2e/ (Playwright), electron/ (paketli exe)
```

Veri akışı: arayüz → server action (`actions.ts`) → SSRF denetimi → `fetch` (15 sn) → rss-parser → öğe
normalizasyonu (`feed-items`) → Prisma upsert. İstemci durumu (seçili feed, filtre, arama) Zustand store'da;
otomatik senkron sayfada zamanlayıcıyla, ayarlanan aralıkta çalışır. Masaüstü kabuğu boş bir yerel portta
sunucuyu başlatır, hazır olunca pencerede açar, pencere kapanınca sunucuyu kapatır.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim + server action (vitest, ayrı `test-results/vitest.db`) | 24 | `npm test` |
| Web e2e (Playwright, port 3204, `prisma/e2e.db`, yerel fikstür feed'leri) | 5 | `npm run test:e2e` |
| Paketli exe (Playwright `_electron`, geçici veri klasörü) | 1 | `publish.ps1` sonunda otomatik |

Testler internete çıkmaz: feed'ler `tests/fixtures/serve.mjs` (port 3214) üzerinden gelir.

## Bilinen sınırlar ve yol haritası

- Ayrıntılı arayüz testi (her kontrol) bu turda yapılmadı; elle test edilecek.
- Tek kullanıcılı; hesap/senkron yok. Otomatik senkron yalnızca uygulama açıkken çalışır.
- Tam metin çıkarma yok: okuyucu feed'in verdiği içeriği gösterir.
- Exe ~490 MB (Electron + Next standalone). Yol haritası: koyu tema, okunmuşları otomatik temizleme.
