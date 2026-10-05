# Kayıtlı Okuma — Web Clipper ve Okuma Listesi

Sayfaları kaydedip yan panelde okumanızı sağlayan Chrome (MV3) eklentisi; isteğe bağlı Next.js web arayüzü ve aynı
arayüzün bağımsız masaüstü (exe) sürümüyle.

![Ekran görüntüsü](docs/ekran.png)

*Ekran görüntüsü, geçici bir veritabanındaki demo kayıtlarla web arayüzünü gösterir.*

## Özellikler

- Popup'tan geçerli sayfayı etiketle kaydet; seçili metin vurgu olarak eklenir
- Yan panelde okuma listesi: okunmamış / yıldızlı / etiket filtresi, arama, okuma modu
- Veriler eklentide (`chrome.storage.local`) — sunucu gerekmez
- Ayarlar sayfasında JSON yedekleme, içe aktarma, tümünü silme
- Web arayüzü (opsiyonel): RSS ve Omnivore içe aktarma, Readability ile makale ayrıştırma, vurgular ve notlar
- Web arayüzü: **eklentiyle uyumlu JSON yedeği** — eklentinin "JSON indir" dosyası web/masaüstü arayüzüne,
  web arayüzünün yedeği eklentiye yüklenebilir (Ayarlar → Yedek); tümünü silme
- Web arayüzü: okuyucudan kaydı silme, okundu/okunmadı geçişi; yalnızca özeti olan (RSS/Omnivore) kayıtlarda
  "Tam metni getir"
- Ayrıştırma: sayfanın karakter kümesine göre çözme (windows-1254 / ISO-8859-9 Türkçe siteler bozulmaz),
  aynı anda en fazla 3 sayfa indirme, yalnızca http(s) adresler, yerel ağa (yönlendirme dahil) istek yok
- Klavye: `J`/`K` gezin, `O` oku, `S` yıldızla, `M` okundu, `/` ara

## Hızlı başlangıç

**Chrome eklentisi**

1. Chrome → `chrome://extensions` → sağ üstte **Geliştirici modu**nu açın
2. **Paketlenmemiş öğe yükle** → bu projedeki `extension/` klasörünü seçin
3. Bir sayfada eklenti ikonu → Kaydet; okuma listesi için popup'taki liste düğmesi (yan panel)

Eklenti kodunu değiştirdikten sonra `chrome://extensions` üzerinden Yenile'ye basın. Eklenti ile web/masaüstü
arayüzü senkronize değildir; kayıtları JSON yedeğiyle taşıyın.

**Web arayüzü / masaüstü sürümü (opsiyonel)**

```powershell
dist\web-clipper-ve-okuma-listesi\KayitliOkuma.exe   # .\publish.ps1 ile üretilmiş masaüstü sürümü
.\run.ps1          # gerekirse .env, npm ci, prisma db push; ardından http://localhost:3107
.\run.ps1 -Check   # birim testleri (vitest) + tip kontrolü + Playwright e2e
.\publish.ps1      # Next standalone derleme + Electron paketi -> dist\web-clipper-ve-okuma-listesi\
```

Elle: `npm install`, `copy .env.example .env`, `npx prisma db push`, `npm run dev` → `http://localhost:3107`.
Diğer: `npm test` (Vitest), `npm run build`, `docker compose up` (konteynerde 3000 portu). Gereksinimler: Chrome 116+
(yan panel API'si), web arayüzü için Node.js 20+.

Exe: Electron kabuğu + Next standalone sunucu; hedef makinede Node gerekmez. Chrome eklentisi exe'ye dahil değildir,
yukarıdaki gibi yüklenir.

## Kullanım

- **Eklenti:** sayfada popup'ı açın, etiketleri virgülle yazın (ya da hızlı etiketlere tıklayın), **Kaydet**. Yan paneldeki
  listede Tümü / Okunmamış / Yıldızlı filtreleri, etiket satırı ve arama kutusu bulunur; bir kayda tıklayınca
  okuyucu açılır (yıldızla, okundu, sil, kaynağa git).
- **Web / masaüstü:** sol menüde Tümü / Okunmamış / Yıldızlı sayaçları ve etiketler; üstte arama; sağ üstte **İçe Aktar**
  sayfası (Omnivore dışa aktarımı, RSS adresi, tek tek URL). Okuyucuda metin seçince vurgu eklenir ve not yazılabilir.
- **Ayarlar:** JSON yedek indir / yükle, eklenti yükleme notu, tüm kayıtları silme ("Tehlikeli bölge").

| Kısayol | İşlev (web / masaüstü arayüzü) |
| --- | --- |
| `J` / `K` | Listede sonraki / önceki kayda git |
| `O` | Seçili kaydı oku |
| `S` | Seçili kaydı yıldızla |
| `M` | Okundu / okunmadı |
| `/` | Aramaya odaklan |

## Veri ve gizlilik

- **Eklenti:** tüm kayıtlar tarayıcıda `chrome.storage.local` içinde (`unlimitedStorage` izniyle) tek bir dizi olarak
  tutulur. Eklenti sunucuya istek göndermez; sayfa metni açık sekmeden `scripting` ile çıkarılır
  (izinler: `activeTab`, `storage`, `unlimitedStorage`, `scripting`, `sidePanel`; `host_permissions: <all_urls>`).
- **Web arayüzü:** SQLite dosyası — geliştirmede `DATABASE_URL` (`.env.example`: `file:./dev.db`, yani `prisma/dev.db`),
  masaüstü sürümünde `%APPDATA%\Kayitli Okuma\okuma.db` (ilk açılışta boş şablon kopyalanır) ve aynı klasörde
  `server.log`. `NEXT_PUBLIC_APP_URL` yalnızca ayarlar API'sinde gösterilen adrestir (varsayılan `http://localhost:3107`).
- **Ağ erişimi:** yalnızca web arayüzü kayıt eklerken sayfayı, RSS içe aktarırken feed'i ve "Tam metni getir"de makaleyi
  indirir (12 sn zaman aşımı, en çok 2 MB HTML). Yerel ağ adresleri (`localhost`, `127.*`, `10.*`, `192.168.*`,
  `172.16-31.*`, `169.254.*`, `.local`, IPv6 yerel) hem ilk istekte hem yönlendirmeden sonra reddedilir. Hesap,
  telemetri ve üçüncü taraf servis yoktur.
- Not: `npm run dev` / `npm start` Next.js varsayılanıyla tüm ağ arayüzlerini dinler ve kimlik doğrulama yoktur;
  masaüstü sürümü yalnızca `127.0.0.1` üzerinde boş bir portta çalışır.

## Mimari / analiz

Teknoloji (`package.json`): Next.js ^16.3.8 (App Router), React ^19.3.0, Prisma ^6.19.3 + SQLite, Zustand ^5.0.15,
`@mozilla/readability` ^0.5.0 + jsdom ^26.1.0 + DOMPurify ^3.4.16 (ayrıştırma ve temizleme), rss-parser ^3.13.0,
Tailwind CSS ^4.3.0, TypeScript ^6.0.3, Vitest ^3.2.7, Playwright ^1.63.0. Eklenti: Manifest V3, bağımlılıksız düz
JavaScript (`extension/manifest.json` sürüm 2.0.0). Masaüstü kabuğu: Electron (`desktop/package.json`).

```
extension/   eklenti: background.js (servis çalışanı, mesaj API'si), db.js (depolama), popup, sidepanel, options
src/app/     Next.js sayfaları (/, /read/[id], /import, /settings) ve API route'ları
             (clips, tags, highlights, feeds, import/omnivore, backup, settings, stats)
src/lib/     readability.ts (indir + ayrıştır), rss.ts, omnivore.ts, backup.ts (eklenti uyumlu yedek), sanitize.ts,
             format.ts (URL doğrulama, özel ağ denetimi), store.ts (Zustand), tags.ts, clips.ts
src/components/  AppShell, ClipCard/ClipGrid, ReaderView, HighlightPanel, KeyboardManager
prisma/      schema.prisma: Clip, Tag, ClipTag, Highlight, Feed, Setting
scripts/     create-db.mjs (e2e ve şablon veritabanı)
tests/       vitest birim testleri + fixtures (yerel HTML), tests/e2e Playwright
desktop/     Electron kabuğu (main.cjs) — publish.ps1 kullanır
```

Veri akışı (web): `POST /api/clips` yalnızca http(s) adresi kabul eder, aynı URL tekrar gelirse yalnızca etiketleri
günceller; özet verilmemişse `scheduleParse` makaleyi indirip Readability ile ayrıştırır, HTML'i temizleyip içerik,
özet, okuma süresi ve alan adıyla kaydeder (`parseStatus`). Eklentide aynı kayıt, sekmeden çıkarılan metinle doğrudan
`chrome.storage.local`'a yazılır; yedek JSON biçimi iki taraf arasında ortaktır.

Tasarım kararları: eklenti sunucusuz çalışır (veri sahibi kullanıcı); web tarafında SSRF'e karşı özel ağ engeli ve
eşzamanlı indirme sınırı (3); karakter kümesi `Content-Type` ve `<meta charset>` üzerinden çözülür; testler internete
çıkmadan yerel HTML örnekleriyle çalışır.

## Testler

- Vitest: 20 birim testi (`tests/backup-url`, `format-omnivore`, `readability`, `sanitize`) — `npm test`
- Playwright e2e: 7 senaryo (`tests/e2e/app.spec.ts`: sayfaların açılması; `reading-list.spec.ts`: yedekten içe aktar /
  oku / yıldızla / filtrele / sil, vurgu ve not, yedek indirme ve "Tam metni getir", API doğrulaması) — `npm run test:e2e`
- Tip kontrolü: `npm run lint` (`tsc --noEmit`); hepsi birlikte: `.\run.ps1 -Check`
- E2E testleri `prisma/dev.db`'ye dokunmaz: her çalıştırmada sıfırdan kurulan `prisma/e2e.db` ile 3207 portunda ayrı
  bir dev sunucusu başlatılır. Eklenti için otomatik test yoktur.

## Bilinen sınırlar

- Eklenti ile web/masaüstü arayüzü otomatik senkronize olmaz; kayıtlar JSON yedeğiyle taşınır.
- Eklentideki sayfa çıkarımı basit bir sezgiseldir (`article` / `main` gövdesi, en çok 500 KB); Readability yalnızca
  web arayüzünde kullanılır; bu yüzden eklentiyle kaydedilen metin web arayüzündeki ayrıştırmadan daha az temizdir.
- Web arayüzü yerel ağ adreslerini ve yalnızca http(s) dışı şemaları reddeder; bu nedenle intranet sayfaları web
  arayüzünde ayrıştırılamaz (eklentiyle kaydedilebilir).
- Tek kullanıcılı tasarım: hesap, paylaşım ve çok cihazlı eşzamanlama yok; web arayüzünde kimlik doğrulama bulunmaz.
- Eklenti yalnızca Chrome 116+ (yan panel API'si) için yazılmıştır ve paketlenmemiş öğe olarak yüklenir.
