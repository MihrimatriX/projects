# Regex Test ve Öğrenme Aracı

Düzenli ifadeleri canlı test eden, adım adım açıklayan ve Türkçe cheatsheet sunan yerel regex laboratuvarı.

![Ekran görüntüsü](docs/ekran.png)

## Özellikler

**Laboratuvar (`/lab`)**
- Canlı eşleşme vurgulama (CodeMirror 6), `g i m s u y` bayrakları, sözdizimi renklendirme
- Eşleşme tablosu: her eşleşmenin altında yakalama grupları (`$1 <ad> değer`); satıra tıklayınca metinde seçilir
- Replace önizleme (`$1`, `$&`, `$<ad>`), sonucu kopyalama
- Adım adım debugger (F10 / Shift+F10), AST ağacı ve Türkçe açıklama
- ReDoS risk skoru ve uyarısı; riskli kalıplar ve 5000+ karakterlik metinler Web Worker'da, 2 sn zaman aşımı
- PCRE/Python sözdizimi uyumsuzluk uyarıları
- 20 hazır şablon (5'i çip olarak), son 8 kalıp geçmişi, "Geçmişi temizle"
- Kopyala (`/kalıp/bayrak`), eşleşmeleri JSON kopyala, `?s=` sıkıştırılmış paylaşım bağlantısı (kişisel veri uyarılı; yalnızca web)
- Son oturum otomatik saklanır ve geri yüklenir; **Temizle** ile sıfırlanır; F1 ile kısayol yardımı

**Cheatsheet (`/cheatsheet`)**
- Kategorili, aranabilir Türkçe referans kartları
- "Laboratuvarda dene": kalıbı çok satırlı örnek metinle laboratuvara yükler

## Hızlı başlangıç

| Ne | Komut |
|---|---|
| Hazır exe | `dist\regex-test-ve-ogrenme-araci\Regex Test ve Ogrenme.exe` (Node gerekmez) |
| Kaynaktan çalıştır | `.\run.ps1` → http://localhost:3105/lab |
| Hızlı kontrol | `.\run.ps1 -Check` (vitest + tsc + statik export) |
| Arayüz testleri | `.\run.ps1 -UiTest` (Playwright web + Electron kabuğu + varsa paketli exe; pencere açar) |
| Exe üret | `.\publish.ps1` → `dist\regex-test-ve-ogrenme-araci\` |

Diğer: `npm run dev`, `npm run build` + `npm start`, `npm run desktop` (statik export + Electron).

## Kullanım

1. Üstteki çiplerden ya da "Tüm şablonlar" listesinden bir şablon seçin veya kalıbı yazın.
2. Test metnini düzenleyin; eşleşmeler canlı vurgulanır, sağdaki tabloda gruplarıyla listelenir.
3. Bayrakları açıp kapatın, replace önizlemesini deneyin, debugger'da kalıbı adım adım inceleyin.
4. Kalıbı kopyalayın ya da (web'de) paylaşım bağlantısı oluşturun.

| Kısayol | İşlev |
|---|---|
| Ctrl+Enter | Yeniden çalıştır |
| Ctrl+Shift+C | Kalıbı `/kalıp/bayrak` olarak kopyala |
| Ctrl+Shift+M | Eşleşmeleri JSON olarak kopyala |
| F10 / Shift+F10 | Debugger ileri / geri |
| Ctrl+Z / Ctrl+Y | Editörde geri al / yinele (şablon yükleme ayrı adımdır) |
| Esc | ReDoS uyarısını / yardım penceresini kapat |
| F1 | Kısayol yardımı |

## Veri ve gizlilik

- Tüm eşleştirme tarayıcı/Electron içinde çalışır; **ağ erişimi yoktur**.
- Oturum (`regex-lab-session`) ve geçmiş (`regex-lab-history`) `localStorage`'da: web'de tarayıcı profilinde,
  exe'de `%APPDATA%\Regex Test ve Ogrenme\` altında. **Temizle** oturumu, "Geçmişi temizle" geçmişi siler.
- Paylaşım bağlantısı kalıbı ve test metnini URL'de taşır; metinde e-posta, telefon, TC kimlik, kart veya IBAN
  görülürse önce uyarı gösterilir.
- Ortam değişkeni (testler için): `REGEX_LAB_USER_DATA` Electron profil klasörünü değiştirir.

## Mimari / analiz

| Katman | Teknoloji |
|---|---|
| UI | Next.js 16.3 (App Router, statik export), React 19.3, Tailwind CSS 4.3, CodeMirror 6 |
| Durum | Zustand 5 (`src/lib/store.ts`) |
| Regex analizi | Yerleşik `RegExp` (eşleştirme), regexp-tree (AST + açıklama), kendi ReDoS sezgiseli |
| Masaüstü | Electron 44 (`desktop/main.cjs`, `app://` protokolü), electron-builder 26, rcedit (ikon/sürüm) |
| Test | Vitest 5, Playwright 1.63 (web + `_electron`), TypeScript 7, jsdom 30 |

```
src/app/              /, /lab, /cheatsheet
src/components/       LabScreen (ana ekran), RegexEditor, TestTextEditor, RegexDebugger, AstTreeView, AstExplanation
src/lib/regex/        evaluate (eşleşme + grup adları), explain (AST), flavor, presets, worker istemcisi
src/lib/              store, history (oturum/geçmiş), redos, pii, cheatsheet-data, codemirror/ vurgulayıcılar
src/workers/          eşleştirme worker'ı
desktop/              Electron kabuğu: main.cjs, resolve.cjs (güvenli statik yol çözümü)
tests/                vitest; e2e/ Playwright web; electron/ kabuk + exe testi
docs/                 ekran görüntüleri, arayüz testi envanteri
```

Veri akışı: editör → `store.setPattern/setTestText` → `runEvaluation` (riskli kalıp veya büyük metinde Worker,
zaman aşımında worker sonlandırılır) → `evaluateRegex` → eşleşmeler, gruplar, replace, açıklama → UI.
Her değerlendirme bir kuşak numarası taşır; geç gelen eski sonuçlar atılır. URL'den gelen kalıplar
(`?p=`, `?s=`) da aynı güvenli yoldan değerlendirilir.

## Testler

| Tür | Sayı | Komut |
|---|---|---|
| Birim (vitest) | 82 | `npm test` |
| Web arayüz (Playwright, tüm ekranlar) | 17 (+1 isteğe bağlı ekran görüntüsü) | `npm run test:e2e` |
| Electron kabuğu / paketli exe | 2 + 2 | `npx playwright test -c playwright.electron.config.ts` (`DESKTOP_EXE` ile exe) |

Ekran görüntülerini yenilemek: `$env:UPDATE_SCREENSHOTS='1'; npm run test:e2e`.
Kontrol envanteri: [docs/arayuz-testi.md](docs/arayuz-testi.md).

## Bilinen sınırlar ve yol haritası

- Yalnızca JavaScript regex motoru; PCRE/Python farkları uyarı olarak gösterilir, çalıştırılmaz.
- Paylaşım bağlantısı 2048 karakterle sınırlı; masaüstü sürümünde paylaşım yok (adres `app://`).
- Dar ekranda (<1024 px) şablon çipleri gizlenir; sekmeli düzen kullanılır.
- Exe ~320 MB (Electron 44 çalışma zamanı). Yol haritası: test metni dosyadan yükleme, eşleşmeleri CSV dışa aktarma.
