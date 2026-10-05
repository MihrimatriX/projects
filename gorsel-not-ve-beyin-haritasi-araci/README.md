# Görsel Not ve Beyin Haritası

tldraw tuvali üzerinde pano oluşturup yerel SQLite'a otomatik kaydeden, çevrimdışı çalışan Next.js uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- Pano listesi: oluşturma, yeniden adlandırma, silme, **adla arama**
- tldraw tuvali: şekil, ok, metin, serbest çizim; pano içinde yan listeden başka panoya geçiş
- Otomatik kayıt: değişiklikten 2 sn sonra tüm tuval JSON olarak veritabanına yazılır; sayfa değiştirirken,
  sekmeyi/pencereyi kapatırken bekleyen kayıt hemen yazılır
- PNG dışa aktarma (2x ölçek, arka planlı; boş tuval dışa aktarılmaz)
- **JSON yedek**: pano JSON olarak indirilir, ana sayfadaki "İçe aktar" ile yeni pano olarak geri yüklenir
  (tldraw.com'dan indirilen `.tldr` dosyaları da içe aktarılabilir)
- Çevrimdışı çalışır: tldraw ikon/yazı tipi/çevirileri CDN yerine uygulamadan yüklenir
- Okunamayan pano verisi salt okunur açılır, üzerine boş tuval yazılmaz
- İsteğe bağlı bağımsız masaüstü sürümü (Electron kabuğu + Next standalone sunucu; hedef makinede Node gerekmez)

## Hızlı başlangıç

```powershell
dist\gorsel-not-ve-beyin-haritasi-araci\GorselNot.exe   # .\publish.ps1 ile üretilmiş masaüstü sürümü
.\run.ps1          # gerekirse npm ci + prisma db push, ardından http://localhost:3102
.\run.ps1 -Check   # birim testleri (vitest) + tip kontrolü + Playwright e2e
.\publish.ps1      # Next standalone derleme + Electron paketi -> dist\gorsel-not-ve-beyin-haritasi-araci\
```

Elle: `npm install`, `npx prisma db push`, `npm run dev` (production: `npm run build` ve `npm start`; ikisi de
3102 portunu kullanır). `run.ps1` port doluysa hiçbir süreci kapatmaz: uygulama zaten açıksa tarayıcıyı açar,
değilse hata verir. Gereksinim: Node.js 20+.

## Kullanım

1. Ana sayfada **Yeni pano** ile pano oluşturun (ad vermezseniz "Yeni pano" olur); karta tıklayınca tuval açılır.
2. Tuvalde şekil, ok, metin ve çizim ekleyin; "Kaydedildi" bildirimi otomatik kaydın yazıldığını gösterir.
3. Üstteki **PNG İndir** / **JSON** düğmeleriyle dışa aktarın; JSON'u ana sayfadaki **İçe aktar** ile geri yükleyin.

| Kısayol | Nerede | İşlev |
| --- | --- | --- |
| `Ctrl+N` | Ana sayfa | Yeni pano |
| `Ctrl+S` | Pano | Bekleyen değişikliği hemen kaydet |
| `Ctrl+E` | Pano | PNG olarak dışa aktar |
| `Esc` | Pano | Yan pano listesini kapat (dar pencere) |
| `V` `R` `A` `D` `T` `E` | Tuval | tldraw varsayılanları: seç, dikdörtgen, ok, çizim, metin, silgi |

## Veri ve gizlilik

- Tüm panolar yerel SQLite dosyasında tutulur: geliştirme sürümünde `prisma/dev.db`, masaüstü sürümünde
  `%APPDATA%\Gorsel Not\panolar.db` (ilk açılışta boş şablon veritabanı kopyalanır, mevcut veri ezilmez).
  Masaüstü sürümünün sunucu günlüğü aynı klasörde `server.log` olarak yazılır.
- `DATABASE_URL` ortam değişkeni (`file:...` biçiminde) veritabanı dosyasını değiştirir; e2e testleri ve masaüstü
  kabuğu bunu kullanır. Verilmezse `prisma/schema.prisma` içindeki `prisma/dev.db` kullanılır.
- Ağ erişimi yok: tldraw varlıkları (`public/tldraw-assets`) uygulamayla gelir, kod dışarıya istek göndermez.
  Hesap, oturum ve telemetri yoktur. Masaüstü sürümünde sunucu yalnızca `127.0.0.1` üzerinde boş bir portta
  dinler; uygulama dışı bağlantılar varsayılan tarayıcıda açılır.
- Not: `npm run dev` / `npm start` Next.js varsayılanıyla tüm ağ arayüzlerini dinler ve kimlik doğrulama yoktur;
  paylaşımlı ağlarda yalnızca masaüstü sürümünü ya da güvenlik duvarı arkasında çalıştırmayı tercih edin.

## Mimari / analiz

Teknoloji (`package.json`): Next.js ^16.3.8 (App Router, Turbopack), React ^19.3.0, tldraw ^3.15.6
(`@tldraw/assets`), Prisma ^6.19.3 + SQLite, Tailwind CSS ^4.3.0, TypeScript ^6.0.3, Vitest ^3.2.7,
Playwright ^1.63.0. Masaüstü kabuğu (`desktop/package.json`): Electron ^42.11.10 + electron-builder ^26.15.3.

```
prisma/schema.prisma    Board (id, ad, tldraw snapshot JSON, createdAt, updatedAt)
src/app/                ana sayfa (pano listesi), /board/[id], /api/boards ve /api/boards/[id]
src/components/         TldrawBoard (tuval + kayıt), BoardWorkspace (üst çubuk, yan liste, kısayollar),
                        Modal, StatusToast, AppMark
src/lib/board-utils.ts  boşluk kontrolü, ad/veri doğrulama, JSON dışa/içe aktarma
src/lib/prisma.ts       PrismaClient (DATABASE_URL varsa o dosya)
scripts/                create-db.mjs (e2e + şablon db), copy-tldraw-assets.mjs
tests/                  vitest birim testleri, tests/e2e Playwright
desktop/                Electron kabuğu (main.cjs) — publish.ps1 kullanır
```

Veri akışı: tuvaldeki kullanıcı kaynaklı her belge değişikliği 2 sn'lik debounce başlatır; süre dolunca (ya da
sayfa değişirken / pencere kapanırken) tüm store snapshot'ı `PATCH /api/boards/:id` ile SQLite'a yazılır. Pano
açılırken kayıtlı snapshot `loadSnapshot` ile yüklenir.

Tasarım kararları:

- Sunucu, yalnızca JSON nesnesi olan tuval verisini kabul eder; bozuk veri kaydı ezmez (API 400 döner).
- Kayıtlı veri okunamazsa pano salt okunur açılır, üzerine boş tuval yazılmaz.
- "Boş" pano, snapshot'ında hiç şekil kaydı olmayan panodur (listede "boş" etiketi).
- Masaüstü kabuğu Next standalone sunucuyu Electron'un Node'uyla ayrı süreç olarak başlatır ve kapanmadan önce
  bekleyen kaydın yazılmasını (en fazla 5 sn) bekler.

## Testler

- Vitest: 11 birim testi (`tests/board-utils.test.ts`, `tests/format-date.test.ts`) — `npm test`
- Playwright e2e: 5 senaryo (`tests/e2e/boards.spec.ts`: çizim ve kalıcılık, hızlı sayfa geçişinde kayıt,
  arama/yeniden adlandırma/silme, JSON dışa-içe aktarma, API doğrulaması) — `npm run test:e2e`
- Tip kontrolü: `npm run lint` (`tsc --noEmit`)
- Hepsi birlikte: `.\run.ps1 -Check`. E2E testleri `prisma/dev.db`'ye dokunmaz; her çalıştırmada sıfırdan kurulan
  `prisma/e2e.db` ile 3202 portunda ayrı bir dev sunucusu başlatılır.

## Bilinen sınırlar

- Tek kullanıcılı, yerel kullanım için tasarlandı: hesap, paylaşım ve çok kullanıcılı eşzamanlı düzenleme yok.
- Her kayıtta tüm tuval snapshot'ı yeniden yazılır; sürüm geçmişi / geri alma kaydı tutulmaz (yalnızca tuval içi
  geri al/yinele).
- Pano listesi son güncellemeye göre sıralanır; yalnızca ada göre arama vardır, etiket/klasör yoktur.
- PNG dışa aktarma boş tuvalde çalışmaz; dışa aktarma ve içe aktarma yalnızca PNG ve JSON/`.tldr` ile sınırlıdır.
- Masaüstü paketi yalnızca Windows için `dir` hedefiyle üretilir (kurulum sihirbazı yok).
