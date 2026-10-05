# Takım İletişim ve Sohbet Aracı

Kendi sunucunuzda (ya da tek tıkla masaüstünde) çalışan, Slack benzeri anlık takım sohbeti.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Sohbet**
- Genel kanallar, birebir mesaj (DM), thread yanıtları
- Socket.IO ile anlık mesaj, düzenleme, silme, "yazıyor" göstergesi ve çevrimiçi durumu
- Okunmamış rozetleri ve yeni DM/kanallar sayfa yenilemeden görünür
- Markdown (GFM) ve @mention vurgusu; dosya eki (yerel disk, `S3_*` tanımlıysa S3/MinIO)
- Kendi mesajını ve thread yanıtını düzenleme / silme ("(düzenlendi)" etiketi herkese yansır)
- Kanal ve thread başına otomatik taslak; son açılan kanal hatırlanır
- 50'şer mesajlık sayfalama ("Daha eski mesajları yükle")

**Arama ve kısayollar**
- Ctrl+K mesaj araması (↑↓ ile seç, Enter ile kanala git), kanal listesi süzme
- Klavye kısayolları listesi (Ctrl+/)

**Ayarlar**
- Görünen ad değiştirme, koyu / açık tema (kalıcı)
- CI bildirimleri için çoklu gelen webhook (kopyala, test et, sil): `POST /api/webhooks/<token>` `{"text": "..."}`
- KVKK: kişisel veriyi JSON olarak dışa aktarma, e-posta onaylı hesap silme

**Dağıtım**
- Bağımsız Windows masaüstü uygulaması (Electron kabuğu, kuruluma özel gizli anahtar, ilk açılışta demo veri)
- Docker Compose (SQLite + Redis), isteğe bağlı Redis ile çoklu instance, LiveKit sesli kanal belirteci

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\takim-iletisim-ve-sohbet-araci\TakimSohbet.exe` (önce `.\publish.ps1`) |
| Kaynaktan çalıştır | `.\run.ps1` → `http://localhost:3106` (bağımlılık, `.env`, veritabanı ve demo veri otomatik) |
| Birim + tip + e2e testleri | `.\run.ps1 -Check` |
| Arayüz testleri (tüm ekranlar + Electron) | `.\run.ps1 -UiTest` |
| Exe üretme | `.\publish.ps1` → `dist\takim-iletisim-ve-sohbet-araci\` |

Demo hesaplar: `mehmet@acme.local`, `ayse@acme.local`, `can@acme.local` — şifre `demo1234`.

Elle kurulum:

```powershell
npm install
copy .env.example .env
npm run db:setup     # prisma db push + seed
npm run dev          # tsx server.ts (Next + Socket.IO aynı süreçte)
```

Docker: `docker compose up` (SQLite + Redis, port 3000).

## Kullanım

- **Kanal / DM:** sol listeden kanal seçin; sağdaki Üyeler panelinde bir kişiye tıklayınca DM açılır. Alttaki "Yeni kanal" kutusuyla kanal oluşturulur.
- **Thread:** mesajın üzerine gelip ↩ (Thread aç) düğmesine basın; yanıtlar sağ panelde.
- **Düzenle / sil:** kendi mesajınızın üzerinde ✎ ve ✕ düğmeleri.
- **Dosya:** ataş simgesiyle seçin, isterseniz metin ekleyip Gönder.
- **Webhook:** Ayarlar → Webhook / CI → ad + kanal → oluştur; URL'ye `{"text": "Derleme yeşil", "sender": "GitHub"}` gönderin.

| Kısayol | İşlev |
|---|---|
| Ctrl+K | Mesajlarda hızlı arama |
| Alt+↑ / Alt+↓ | Önceki / sonraki kanal |
| Enter / Shift+Enter | Gönder (düzenlemeyi kaydet) / yeni satır |
| Esc | Düzenlemeden vazgeç; thread'i, menüyü veya diyaloğu kapat |
| Ctrl+/ | Kısayol listesi |

## Veri ve gizlilik

- **Kaynaktan:** SQLite `prisma\dev.db`, ekler `uploads\` (`.env`: `DATABASE_URL`, `UPLOAD_DIR`, `SESSION_SECRET`).
- **Masaüstü exe:** `%APPDATA%\Takim Sohbet\` → `sohbet.db`, `uploads\`, `server.log`, `secret.key`
  (kuruluma özel rastgele anahtar; şifre özetleri bununla tuzlanır, silinirse mevcut şifreler geçersiz olur).
  `TAKIM_SOHBET_DATA` ortam değişkeni veri klasörünü değiştirir (testler bunu kullanır).
- **Testler** geçici klasörde (`%TEMP%\takim-sohbet-e2e`) ayrı veritabanı ve 3196 portuyla çalışır; geliştirme verisine dokunmaz.
- **Ağ:** telemetri yok, harici font/CDN isteği yok. Masaüstü sunucusu yalnızca `127.0.0.1` dinler.
  Dışarıya yalnızca sizin yapılandırdığınız Redis / S3 / LiveKit adreslerine bağlanılır.
- Ayarlar → KVKK bölümünden kişisel veri JSON olarak indirilir veya hesap kalıcı olarak silinir.

## Mimari / analiz

**Yığın:** Next.js 16.3 (App Router, standalone) · React 19.3 · Socket.IO 4.8 · Prisma 7.10 (`prisma.config.ts`,
`@prisma/adapter-libsql` sürücü adaptörü, Rust motorsuz sorgu derleyicisi) · SQLite · Zustand 5 · Tailwind CSS 4.3 ·
TypeScript 7 · Vitest 5 · Playwright 1.63 · Electron 44 + electron-builder 26 · esbuild · isteğe bağlı Redis 6 istemcisi.

```
server.ts           HTTP sunucusu: Next istekleri + /api/socket (Socket.IO), .env'i Next'ten önce okur
prisma.config.ts    Prisma 7 yapılandırması (şema, DATABASE_URL, seed)
prisma/             SQLite şeması (+ deneysel PostgreSQL şeması) ve demo seed
src/app/            sayfalar (login, chat, settings) ve API route'ları
src/components/     ChatApp (durum + soket), Sidebar, MessageFeed/Bubble/Composer, ThreadPanel, SearchDialog, SettingsPage
src/lib/            prisma (adaptör), auth(-core), socket-server/-client, channels, messages, search, storage, export
desktop/main.cjs    Electron kabuğu: boş porta paketli sunucuyu başlatır, ilk açılışta şablon db + seed
e2e/                Playwright: chat (ana akış), ui (tüm ekranlar), electron (kabuk), screens (README görüntüleri)
test/               Vitest birim testleri
```

**Veri akışı:** İstemci REST ile yazar (`/api/channels/:id/messages`, `/api/messages/:id` …); route kaydı veritabanına
yazıp olayı Socket.IO'ya yayar (`message:new|update|delete`, `typing:*`, `presence:update`, `channels:changed`).
Soket bağlanınca kullanıcı üyesi olduğu **tüm** kanal odalarına (`channel:<id>`) ve kendi odasına (`user:<id>`) katılır;
yeni kanal/DM açılınca üyelerin soketleri odaya alınır. İstemci tek soket bağlantısı tutar, aktif kanalı ref'ten okur.

**Tasarım kararları**
- `server.ts` ile Next route'ları modülleri ayrı yükler; Socket.IO örneği `globalThis` üzerinden paylaşılır.
- SQLite sürücüsü olarak libsql seçildi: N-API modülü olduğu için aynı ikili hem Node 26'da (geliştirme) hem
  Electron'un Node'unda (masaüstü, `ELECTRON_RUN_AS_NODE`) yeniden derleme gerektirmeden çalışır.
- Oturum httpOnly çerezde; soket el sıkışması aynı çerezi doğrular. Giriş denemeleri hız sınırlıdır.
- Ekler aynı origin'de yalnızca görselse satır içi açılır, diğerleri `attachment` olarak iner.
- Masaüstü paketinde sunucu esbuild ile tek `server.cjs` dosyasına paketlenir; Next/Prisma/libsql standalone `node_modules`'tan gelir.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (Vitest) | 14 | `npm test` |
| E2E ana akış (Playwright) | 4 | `npx playwright test --project=e2e` (`-Check` içinde) |
| Arayüz envanteri (Playwright) | 16 | `npx playwright test --project=ui` (`-UiTest`) |
| Electron kabuğu (Playwright `_electron`) | 1 | `npx playwright test --project=electron` (`-UiTest`; önce `publish.ps1`) |

Playwright sunucuyu kendisi derleyip (`next build`) geçici veritabanıyla başlatır. Ekran/kontrol envanteri:
[docs/arayuz-testi.md](docs/arayuz-testi.md). README görüntüleri: `npx playwright test --project=screens`.

## Bilinen sınırlar ve yol haritası

- `docker-compose.full.yml` (PostgreSQL + MinIO) deneyseldir: uygulama yalnızca SQLite sürücü adaptörüyle gelir;
  PostgreSQL için `prisma/schema.postgres.prisma` ile istemci üretip `@prisma/adapter-pg` eklemek gerekir.
- Özel (davetli) kanal, mesaj tepkileri (emoji), sabitlenmiş mesajlar ve masaüstü bildirimi henüz yok.
- Arama SQLite `LIKE` kullanır; Türkçe büyük/küçük harf (İ/ı) eşleşmesi tam değildir.
- Masaüstü paketi ~430 MB (Electron + Next standalone); imzasızdır, SmartScreen uyarısı görülebilir.
- Eski kurulumlarda `.env` içindeki `DATABASE_URL="file:./dev.db"` Prisma 7 ile proje köküne göre çözülür;
  mevcut veritabanını kullanmak için `file:./prisma/dev.db` yapın.
