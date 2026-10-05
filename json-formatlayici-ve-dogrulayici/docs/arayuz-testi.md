# Arayüz testi envanteri

Otomatik testler: `tests/e2e/app.spec.ts` (Playwright, Chromium, dev sunucu) ve `tests/electron/shell.spec.ts`
(Playwright `_electron`, kaynak kabuk ve paketli exe). Hepsi `.\run.ps1 -UiTest` ile çalışır.
Sonuç sütunu son çalıştırmayı gösterir (web 20/20, Electron 2/2 kaynak + 2/2 exe).

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Başlatıcı `/` | 5 ekran kartı | Her kart ilgili ekranı açar | Geçti | |
| Tüm ekranlar | Araç çubuğu gezintisi (Ekranlar, Lab, JSONPath, Şema, Diff, Dosya) | Rota değişir, 1280 px'de araç çubuğu taşmaz | Geçti | Düzeltildi: düğmeler 44 px çubuktan taşıp kesiliyordu |
| Laboratuvar | Boş durum | Bekliyor rozeti, işlem düğmeleri devre dışı, ağaç ipucu | Geçti | |
| Laboratuvar | Ağaç paneli (geniş ekran) | Editör ile yan yana görünür | Geçti | Düzeltildi: mobil sekme kuralı her genişlikte uygulanıyor, ağaç hiç görünmüyordu |
| Laboratuvar | Format / Minify / Sırala + Ctrl+Shift+F/M | Satır sayısı ve girinti değişir, anahtarlar sıralanır | Geçti | "Sort keys" → "Sırala" |
| Laboratuvar | Durum çubuğu: Boşluk 2/4 | Format girintisi değişir, yeniden açılışta korunur | Geçti | Seçim araç çubuğundan durum çubuğuna taşındı |
| Laboratuvar | Durum çubuğu: Giriş modu JSON/NDJSON | NDJSON satırları geçerli olur, Sırala devre dışı; Temizle JSON'a döner | Geçti | Yeni: önceden arayüzden değiştirilemiyordu |
| Laboratuvar | Durum çubuğu: JSONC onay kutusu | Yorumlar kapalıyken hata, açıkken geçerli; kalıcı | Geçti | Yeni: ayar vardı ama bağlı değildi |
| Laboratuvar | Ctrl+Z (editör) | Format işlemi tek adımda geri alınır | Geçti | Düzeltildi: format, son yazımla aynı geri-al adımına birleşiyordu |
| Laboratuvar | Ağaç: ara, Genişlet/Daralt | Eşleşme vurgulanır, tüm düğümler açılır/kapanır | Geçti | Arama kutusuna erişilebilir ad eklendi |
| Laboratuvar | Ağaç dalı (Enter/Boşluk) | `aria-expanded` değişir | Geçti | Düzeltildi: dallar klavyeyle açılamıyordu |
| Laboratuvar | Ağaç: Path / Ptr / Kopyala | JSONPath, JSON Pointer, değer panoya | Geçti | Düzeltildi: düğmeler yalnızca fareyle görünürdü, adları yoktu |
| Laboratuvar | Kopyala / TS tipi / Paylaş | Panoya içerik, TypeScript tipi, `#d=` bağlantısı; bağlantı içeriği açar | Geçti | Yeni düğmeler; Paylaş masaüstünde gizli |
| Laboratuvar | ? düğmesi, F1, Esc, Kapat, arka plan | Yardım penceresi açılır/kapanır | Geçti | Yeni: yardım yalnızca F1 ile açılıyordu |
| Laboratuvar | Hatalı JSON rozeti + Onar | Hata paneli, ağaç "Geçerli JSON gerekli", Onar düzeltir | Geçti | |
| Laboratuvar | Aç (dosya seçici), Kaydet, Ctrl+S | Dosya adı başlıkta, indirme dosya adını korur | Geçti | Electron'da gerçek dosyaya yazılır |
| Laboratuvar | Taslak | Yeniden yüklemede geri gelir, Temizle siler | Geçti | Düzeltildi: kapanıştan <500 ms önceki değişiklik kayboluyordu (pagehide'da yazılır) |
| Laboratuvar | Sürükle-bırak, 5 MB üstü | Dosya yüklenir; büyük dosyada İptal / Yine de yükle | Geçti | |
| Laboratuvar | Panel ayırıcı (ok tuşları) | Panel genişliği değişir | Geçti | Yeni: ayırıcı odaklanabiliyordu ama klavyeyle çalışmıyordu |
| Laboratuvar | Dar ekran (390 px) Editör/Ağaç sekmeleri | Tek panel görünür, sekmeyle değişir | Geçti | |
| JSONPath | Sorgula, Enter | `$...` JSONPath ve `.a | .[]` jq-lite sonuçları listelenir | Geçti | Düzeltildi: `$` ile başlayan sorgular hiç sonuç vermiyordu |
| JSONPath | Eşleşme yok / geçersiz kaynak | "Eşleşme yok", "0 sonuç" / "Geçersiz JSON" | Geçti | Düzeltildi: eşleşmesiz sorgu `[undefined]` (1 sonuç) dönüyordu |
| JSONPath | Sonucu editöre yaz | Laboratuvar editöründe sonuç | Geçti | Sorgu kutusu 80 px yüksekliğindeydi, düzeltildi |
| Şema | Doğrula (şema boşken) | Devre dışı + yönlendirici ipucu | Geçti | Düzeltildi: boş şemada düğme tepkisizdi |
| Şema | Örnek şema, hata listesi, Ctrl+Enter | Geçerli / N şema hatası | Geçti | Sonuç başlığına `aria-live` eklendi |
| Diff | Karşılaştır, özet rozeti | `+1 −1 ~1`, değişen yollar listesi | Geçti | |
| Diff | Satır vurgusu | Yalnızca gerçekten farklı satırlar işaretlenir (LCS) | Geçti | Düzeltildi: her 3. satır sahte olarak vurgulanıyordu; girinti korunuyor |
| Diff | Geçersiz/boş JSON | Hangi tarafın hatalı olduğu `role=alert` ile | Geçti | Düzeltildi: hata "1 değişiklik" gibi gösteriliyordu |
| Diff | Sol = editör / Sağ = editör / Değiştir ⇄ / Fark yok | Metinler alınır, yer değiştirir, eski sonuç gizlenir | Geçti | Sağ = editör ve Değiştir yeni |
| Diff | Sağ JSON paneli | Sol ile eşit genişlik | Geçti | Düzeltildi: iki panel %40 genişlikte kalıyordu |
| Dosya | Boş durum, Aç, önizleme, satır sayısı, Kaydet | Dosya adı, önizleme, indirme | Geçti | Düzeltildi: önizleme paneli geniş ekranda gizliydi; boş metin kesiliyordu |
| Dosya | İzle | Yalnızca Tauri'de görünür | Geçti | Web/Electron'da işlevsiz düğme kaldırıldı |
| Dosya | Dar ekran Dosyalar/Önizleme sekmeleri | Sekmeyle değişir | Geçti | |
| Electron | Açılış, pencere başlığı, `app://local/lab` | Laboratuvar açılır | Geçti | Kaynak ve paketli exe |
| Electron | Tüm ekranlar + Kaydet + pano + yeniden açılışta taslak/ayar | Çalışır; profil geçici klasörde | Geçti | `JSON_LAB_USER_DATA`, `JSON_LAB_DOWNLOAD_DIR` |
| Electron | Olmayan rota | 404 sayfası | Geçti | |
