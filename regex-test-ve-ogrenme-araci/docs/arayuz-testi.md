# Arayüz testi envanteri

Otomatik testler: `tests/e2e/lab.spec.ts` (Playwright, Chromium, üretim derlemesi `next start`) ve
`tests/electron/shell.spec.ts` (Playwright `_electron`, kaynak kabuk ve paketli exe). Hepsi `.\run.ps1 -UiTest` ile çalışır.
Son çalıştırma: web 17/17 (+1 isteğe bağlı ekran görüntüsü), Electron 2/2 kaynak + 2/2 exe.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana sayfa | Laboratuvar / Cheatsheet kartları, "Laboratuvara git" | İlgili ekran açılır | Geçti | "1280px üstünde" ve "readonly hash" gibi yanlış metinler düzeltildi |
| Laboratuvar | Yerleşim (≥1024 px) | Pattern üstte, test metni altta, sonuç paneli sağda iki satırı kaplar | Geçti | Düzeltildi: test metni sağ üste kayıyor, sonuç paneli sıkışıyor, sol alt boş kalıyordu |
| Laboratuvar | Başlık çubuğu | 1280 px'de taşmaz | Geçti | |
| Laboratuvar | Pattern / test metni editörleri | Erişilebilir adla (`Regex pattern`, `Test metni`) yazılabilir | Geçti | Düzeltildi: ad dış kaba verilmişti, metin kutusu adsızdı |
| Laboratuvar | Eşleşme tablosu satırı (tık / Enter) | `aria-selected`, test metninde seçili eşleşme | Geçti | Yeni: seçim durumu vardı ama hiçbir yerden değiştirilemiyordu |
| Laboratuvar | Yakalama grupları | Her eşleşmenin altında `$1 <ad> değer` | Geçti | Düzeltildi: "Yakalama grupları" tablosu grupları hiç göstermiyordu |
| Laboratuvar | Bayraklar g i m s u y | `aria-pressed`, eşleşme sayısı değişir | Geçti | |
| Laboratuvar | Hatalı pattern | Durum "Syntax hatası", tablo mesajı, debugger uyarısı | Geçti | |
| Laboratuvar | 5 şablon çipi + "Tüm şablonlar" | Her biri ≥1 eşleşme | Geçti | |
| Laboratuvar | Geçmiş listesi, "Geçmişi temizle" | Kayıt yüklenir, liste kaldırılır | Geçti | |
| Laboratuvar | Replace önizleme + "Sonucu kopyala" | `$&`, `$<ad>` uygulanır, panoya yazılır | Geçti | "Sonucu kopyala" yeni |
| Laboratuvar | Kopyala, Ctrl+Shift+C, Ctrl+Shift+M, "JSON kopyala" | `/kalıp/bayrak`, eşleşme JSON'u panoda; bildirim | Geçti | Düzeltildi: pano hatasında da "kopyalandı" deniyordu; kısayollar sessizdi; "JSON kopyala" yeni |
| Laboratuvar | Paylaş | Kişisel veri uyarısı (İptal / Yine de paylaş), `?s=` bağlantısı yeni sekmede kalıbı açar | Geçti | Masaüstünde (app://) gizli; boş kalıpta devre dışı |
| Laboratuvar | ReDoS uyarısı + "Uyarıyı kapat" / Esc | Uyarı görünür ve kapanır | Geçti | |
| Laboratuvar | 6000 karakterlik metin | Worker'da 3000 eşleşme | Geçti | |
| Laboratuvar | Debugger: Adım (İleri, F10, Shift+F10), AST, Açıklama | Adım sayacı ilerler/geriler, sekme `aria-pressed` | Geçti | Sekmelere `aria-pressed` eklendi |
| Laboratuvar | ? düğmesi, F1, Esc, arka plan | Kısayol penceresi açılır/kapanır | Geçti | Yeni |
| Laboratuvar | Şablon yükleme sonrası Ctrl+Z | Önceki kalıba döner | Geçti | Düzeltildi: programatik değişiklik yazımla aynı geri-al adımına birleşiyordu |
| Laboratuvar | Oturum geri yükleme (hemen yeniden yükleme) + Temizle + Ctrl+Enter | Kalıp/metin geri gelir; temizlenir | Geçti | Düzeltildi: kapanıştan <500 ms önceki değişiklik kayboluyordu (pagehide'da yazılır) |
| Laboratuvar | Dar ekran Pattern / Test / Sonuç sekmeleri | `role=tablist`, tek panel görünür | Geçti | `tablist` rolü eklendi |
| Laboratuvar | Alt bilgi "Ana sayfa" | Ana sayfa açılır | Geçti | |
| Cheatsheet | Arama kutusu | Kartlar süzülür, sonuç yoksa mesaj | Geçti | Yeni |
| Cheatsheet | Laboratuvarda dene | Kalıp, eşleşen çok satırlı örnek metinle açılır | Geçti | Düzeltildi: "Örnek metin buraya" metninde çoğu kalıp hiç eşleşmiyordu |
| Cheatsheet | ← Laboratuvara dön | Laboratuvar açılır | Geçti | |
| Electron | Açılış `app://local/lab`, worker, gruplar, pano, yardım, debugger, şablon | Çalışır | Geçti | Kaynak ve paketli exe |
| Electron | Yeniden açılışta oturum + geçmiş, cheatsheet, ana sayfa, 404 | Çalışır; profil geçici klasörde | Geçti | Düzeltildi: test gerçek profildeki localStorage'ı siliyordu → `REGEX_LAB_USER_DATA` |
