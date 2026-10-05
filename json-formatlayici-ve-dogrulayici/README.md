# JSON Formatlayıcı ve Doğrulayıcı

JSON'u yerelde formatlayan, doğrulayan, sorgulayan ve karşılaştıran VS Code tarzı araç; veri hiçbir sunucuya gitmez.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Laboratuvar (`/lab`)**
- CodeMirror 6 editör + sanal (virtualized) ağaç; sürüklenebilir / klavyeyle (← →) ayarlanabilir ayırıcı
- Format, Minify, anahtarları Sırala; girinti 2/4 boşluk (durum çubuğundan, kalıcı)
- Satır/sütunlu hata paneli, **Onar** (tek tırnak, sondaki virgül, BOM)
- JSON / NDJSON giriş modu ve JSONC (yorumlu JSON) anahtarı — durum çubuğunda, kalıcı
- Yinelenen anahtar uyarısı; 512 KB üstü metin Web Worker'da; 5 MB üstü dosyada onay
- Ağaçta arama, tümünü genişlet/daralt, düğüm başına JSONPath / JSON Pointer / değer kopyalama
- **Kopyala**, **TS tipi** (JSON'dan TypeScript tipi), **Paylaş** (içeriği taşıyan `#d=` bağlantısı; yalnızca web)
- Dosya **Aç / Kaydet** (Ctrl+O / Ctrl+S, sürükle-bırak); editör taslağı otomatik saklanır (1 MB'a kadar)
- Editörde geri al / yinele: Format gibi işlemler ayrı adım olarak geri alınır

**Diğer ekranlar**
- `/jsonpath`: `$...` JSONPath (jsonpath-plus) ve `.a | .[] | .b` jq-lite sorguları, sonucu editöre yazma
- `/schema`: JSON Schema (Draft-07, Ajv) doğrulama, alan bazlı hata listesi, örnek şema
- `/diff`: yol bazlı özet (+ − ~), formatlı metinlerde gerçek satır farkı (LCS), yer değiştir
- `/file`: aktif dosya, önizleme; Tauri sürümünde son dosyalar ve dış değişiklik izleme

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\json-formatlayici-ve-dogrulayici\JSON Formatlayici.exe` (Node gerekmez) |
| Kaynaktan çalıştır | `.\run.ps1` → http://localhost:3103/lab |
| Hızlı kontrol | `.\run.ps1 -Check` (vitest + tsc + statik export) |
| Arayüz testleri | `.\run.ps1 -UiTest` (Playwright web + Electron kabuğu + varsa paketli exe; pencere açar) |
| Exe üret | `.\publish.ps1` → `dist\json-formatlayici-ve-dogrulayici\` |

Diğer: `npm run desktop` (statik export + Electron), `npm run tauri:dev` / `tauri:build` (Rust gerekir).

## Kullanım

1. **Demo** ile örnek veri yükleyin ya da JSON yapıştırın / dosya sürükleyin.
2. Rozet geçerliliği gösterir; hatada rozete tıklayıp **Onar**'ı deneyin.
3. Ağaçta arayın, düğümün yolunu kopyalayın; **JSONPath** ekranında sorgulayın.
4. **Şema** ekranında doğrulayın, **Diff** ekranında iki sürümü karşılaştırın.

| Kısayol | İşlev |
|---|---|
| Ctrl+Shift+F | Format |
| Ctrl+Shift+M | Minify |
| Ctrl+Shift+K | Anahtarları sırala |
| Ctrl+O / Ctrl+S | Dosya aç / kaydet (indir) |
| Ctrl+Z / Ctrl+Y | Geri al / yinele (editörde) |
| Ctrl+Enter | Şema ekranında doğrula |
| Enter | JSONPath ekranında sorgula |
| ← / → | Odaklı panel ayırıcısını kaydır |
| F1 | Yardım (Esc kapatır) |

## Veri ve gizlilik

- Tüm parse, sorgu ve doğrulama tarayıcı/Electron içinde çalışır; **ağ erişimi yoktur** (fontlar derlemeye gömülü).
- Taslak ve ayarlar (girinti, JSONC, son dosyalar) `localStorage`'da: web'de tarayıcı profilinde, exe'de
  `%APPDATA%\JSON Formatlayici\` altında.
- Paylaşım bağlantısı içeriği URL'nin `#` kısmında (lz-string) taşır; sunucuya gönderilmez.
- Ortam değişkenleri (testler için): `JSON_LAB_USER_DATA` Electron profil klasörünü, `JSON_LAB_DOWNLOAD_DIR`
  Kaydet'in "Farklı kaydet" penceresi yerine yazacağı klasörü belirler.

## Mimari / analiz

| Katman | Teknoloji |
|---|---|
| UI | Next.js 16.3 (App Router, statik export), React 19.3, Tailwind CSS 4.3, CodeMirror 6 |
| Durum | Zustand 5 (tek store: `src/lib/store.ts`) |
| Doğrulama / sorgu | Ajv 8, jsonpath-plus 11, kendi jq-lite'ı (eval yok) |
| Masaüstü | Electron 44 (`desktop/main.cjs`, `app://` protokolü), electron-builder 26, rcedit (ikon/sürüm) |
| Alternatif masaüstü | Tauri 2 (`src-tauri/`, dosya izleme) |
| Test | Vitest 5, Playwright 1.63 (web + `_electron`), TypeScript 7 |

```
src/app/          ekranlar: / (başlatıcı), lab, jsonpath, schema, diff, file
src/components/   CodeMirrorEditor, VirtualJsonTree, modallar, shell/ (araç çubuğu, durum çubuğu, rozet)
src/lib/          store, parse/ (worker), jsonc, ndjson, json-diff (yol + LCS satır farkı), jq-lite,
                  jsonpath-query, schema-validate, share-url, ts-interface, file-io, tauri-bridge
desktop/          Electron kabuğu: main.cjs (pencere, app:// eşlemesi, indirme), resolve.cjs (güvenli yol çözümü)
tests/            vitest birim testleri; e2e/ Playwright web; electron/ kabuk + exe testi
docs/             ekran görüntüleri, arayüz testi envanteri
```

Veri akışı: editör/dosya/paylaşım → `store.setRawJson` → (JSONC soyma) → parse (büyükse Worker) →
`parsedJson` → ağaç, JSONPath vurgusu, şema doğrulaması. Her parse isteği bir kimlik taşır; yalnızca en son
sonuç uygulanır. Electron kabuğu Next statik export'unu (`out/`) `app://local/` altında sunar, kök dışına
çıkan yolları reddeder ve dış bağlantıları varsayılan tarayıcıda açar.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (vitest) | 38 | `npm test` |
| Web arayüz (Playwright, tüm ekranlar) | 20 (+1 isteğe bağlı ekran görüntüsü) | `npm run test:e2e` |
| Electron kabuğu / paketli exe | 2 + 2 | `npx playwright test -c playwright.electron.config.ts` (`DESKTOP_EXE` ile exe) |

Ekran görüntülerini yenilemek: `$env:UPDATE_SCREENSHOTS='1'; npx playwright test -g "ekran"`.
Kontrol envanteri: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Tauri sürümü Rust gerektirir (bu makinede kurulu değil; exe Electron ile üretilir). Dış değişiklik izleme
  ve "son dosyalar" yalnızca Tauri'de çalışır.
- Diff satır vurgusu O(n·m) LCS kullanır; 4 milyon hücre üstünde (≈2000×2000 satır) vurgu yapılmaz, yol özeti çalışır.
- Taslak 1 MB, paylaşım bağlantısı 200 KB ile sınırlı.
- Exe ~320 MB (Electron 44 çalışma zamanı). Yol haritası: tema seçimi (açık tema), JSON → CSV/YAML dışa aktarma.
