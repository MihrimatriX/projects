# HookYerel — Yerel Webhook Test Aracı

Webhook isteklerini internete açmadan `127.0.0.1` üzerinde yakalayan, mock yanıt veren ve imzaları doğrulayan Electron masaüstü uygulaması.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

- **Yakalama:** `http://127.0.0.1:<port>/hook/<slug>` (varsayılan 8787; port doluysa sonraki 5 port denenir), açılışta otomatik başlar, birden çok endpoint
- **İnceleme:** canlı istek listesi, başlık/gövde detayı, JSON biçimlendirme, path/gövde/başlık araması, yöntem çipleri
- **Araçlar:** replay (yalnızca localhost), curl olarak kopyalama, endpoint başına mock yanıt kuralları (yöntem + path regex + durum + gövde)
- **Güvenlik:** Stripe / GitHub / Shopify HMAC imza doğrulama (Stripe anahtar rotasyonundaki çoklu `v1` dahil), Authorization/imza başlıklarını ve gizli gövde alanlarını maskeleme, yalnızca loopback
- **Veri:** SQLite'ta saklama, saklama sınırı, gövde boyutu sınırı, JSON günlük dışa aktarma; silme işlemleri onaylı

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\yerel-webhook-test-araci\HookYerel.exe` (kurulum gerektirmez) |
| Kaynaktan çalıştır | `.\run.ps1` (Vite **5174** + Electron), `.\run.ps1 -Prod` (derle + çalıştır) |
| Tip kontrolü + birim testleri + derleme | `.\run.ps1 -Check` |
| Arayüz + e2e testleri (pencere açar) | `.\run.ps1 -UiTest` |
| Exe üret | `.\publish.ps1` (veya `.\run.ps1 -Build`) → `dist\yerel-webhook-test-araci\` |
| Kurulum paketi (NSIS) | `npm run pack` → `release\` |

Gereksinim (kaynaktan): Node.js 22.12+.

## Kullanım

Uygulama açılınca sunucu dinlemeye başlar; sol listedeki endpoint'in URL'ini kopyalayıp webhook gönderen servise verin. Gelen istekler anında listede belirir ve seçilir. Detayda "İmza doğrulama" bölümünden preset + secret ile imzayı doğrulayın, "Replay" ile isteği tekrar gönderin. Kenar çubuğu başlığındaki "Mock kuralları" düğmesi kuralları açar (eşleşen en yüksek öncelikli kural yanıtı belirler; kural yoksa `200`).

| Kısayol | İşlev |
|---|---|
| `↑` / `↓` | İstekler arasında gezin |
| `r` | Seçili isteği yeniden gönder |
| `c` | Seçili isteği curl olarak kopyala |
| `f` veya `/` | Filtreye odaklan |
| `Ctrl+N` | Yeni endpoint |
| `Ctrl+L` | Aktif endpoint URL'ini kopyala |
| `?` | Kısayol yardımı |
| `Esc` | Pencereyi / çekmeceyi kapat |

## Veri ve gizlilik

- Veritabanı: Electron `userData` klasöründe `hookyerel.db` (`%APPDATA%\yerel-webhook-test-araci\`). `HOOKYEREL_DATA_DIR` ortam değişkeni bu klasörü değiştirir (testler / taşınabilir kullanım).
- Sunucu yalnızca `127.0.0.1`'de dinler; replay yalnızca loopback adreslere gönderir. Uygulama dışarıya bağlantı açmaz.
- Maskeleme açıkken gizli başlık/gövde alanları arayüzde gizlenir; imza doğrulaması ham gövdeyle yapılır. Dışa aktarılan JSON yine de hassas veri içerebilir.

## Mimari / analiz

**Yığın:** Electron 44.5, React 19.3, Vite 8.3 (vite-plugin-electron 1.1, @vitejs/plugin-react 6), TypeScript 7, better-sqlite3 13 (N-API), @tanstack/react-virtual; testler Vitest 5 + Playwright 1.63 `_electron`; paketleme electron-builder 26 + rcedit.

```
electron/
  main.ts          pencere, IPC uçları, replay, dışa aktarma
  hookServer.ts    Node http sunucusu: slug çözümü, gövde sınırı, mock yanıt, port geri düşüşü
  db.ts            SQLite şeması (endpoint, istek, mock kuralı, ayar), maskeleme, saklama sınırı
  mock.ts          kural eşleme (yöntem + path regex + öncelik)
  signature.ts     Stripe / GitHub / Shopify HMAC doğrulama
  server-utils.ts  loopback denetimi, yardımcılar
  preload.ts       contextBridge API'si
src/               React arayüzü (App.tsx durum, components/, hooks/useKeyboardNav, lib/ saf yardımcılar)
tests/             Vitest (gerçek soketlerde HTTP sunucusu, imza, mock, filtre)
e2e/               Playwright Electron: ui.spec.ts (arayüz envanteri), app.spec.ts (uçtan uca akış), screenshots.spec.ts
```

**Veri akışı:** HTTP isteği → `hookServer` (slug → endpoint, mock kuralı → yanıt) → `insertRequest` (SQLite, maskeleme) → IPC `webhook:request` → React listesi (sanal kaydırma) → detay.

**Tasarım kararları:** better-sqlite3 13 N-API hazır ikiliyle gelir; Node (vitest) ve her Electron sürümü aynı ikiliyi kullanır, yeniden derleme gerekmez. Ana süreç tek dosyaya paketlenir, exe'ye yalnızca better-sqlite3'ün `win32-x64` ikilisi eklenir.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (Vitest) | 24 | `npm test` |
| Arayüz (Playwright `_electron`) | 3 | `npx playwright test ui` |
| E2E: yakalama, maskeleme, arama, imza, mock | 1 | `npx playwright test app` |
| README ekran görüntüsü | 1 (varsayılan atlanır) | `$env:HOOK_SCREENSHOTS=1; npx playwright test screenshots` |

Kontrol envanteri: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Tema yalnızca koyu.
- İstek listesindeki göreli zaman ("az önce") liste yenilenene kadar güncellenmez.
- Mock kuralları düzenlenemez (silip yeniden eklenir); öncelik arayüzden ayarlanamaz.
- Yol haritası: kural düzenleme, istek gövdesini düzenleyip replay, HAR dışa aktarma.
