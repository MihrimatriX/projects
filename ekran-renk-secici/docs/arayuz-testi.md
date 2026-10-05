# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (FlaUI/UIA3, 2 test; gecici veri klasoru `EKRAN_RENK_SECICI_DATA_DIR`, pano sonra geri
yuklenir, gercek girdi ve ekran kopyalama `.gui.lock` icinde). Kullanici karariyla UI paketi bu turda son kez
calistirilmadi; elle dogrulama bekleniyor.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana pencere | "Ekrandan Seç (kısayol)" düğmesi | Kısayolu içeren etiket | Hata bulundu → düzeltildi | `StringFormat` Content'te çalışmıyordu, yalnızca "Ctrl+Shift+C" yazıyordu |
| Ana pencere | Boş durum | "Ekrandan bir renk seçin…" + düğme | Testte | Düğme metni "Pick modunu aç" → "Ekrandan renk seç" |
| Ana pencere | Renk kodu kutusu + Enter | Geçersiz → uyarı; geçerli → geçmiş + ayrıntı | Testte | |
| Ana pencere | Geçmiş listesi | Satır adı = HEX | Düzeltildi | Ekran okuyucu sınıf adını okuyordu |
| Ana pencere | HEX/RGB/HSL/OKLCH/CSS Kopyala | Panoya + durum mesajı | Testte | Beş düğmenin adı aynıydı → "HEX kopyala" vb. |
| Ana pencere | Kontrast (Beyaz/Koyu/Tamamlayıcı), renk körlüğü çipleri | Oran/önizleme değişir | Testte | |
| Ana pencere | Tamamlayıcı / analog renk | HEX panoya | Testte | Renk düğmelerinin erişilebilir adı yoktu → eklendi |
| Dışa aktar | Tailwind / Figma / CSS sekmeleri, Kopyala | Metin değişir, panoya + kapanır | Testte | Düğme "Kopyala ve kapat" (kapanması beklenmiyordu) |
| Ayarlar | Format, örnekleme, zoom, tuş; İptal / Kaydet | İptal yazmaz, Kaydet yazar + etiket güncellenir | Testte | Enter/Esc (IsDefault/IsCancel) eklendi |
| Seçim katmanı | Format sekmeleri, 1×1/5×5, Tab, 5, Esc, Enter | Değer formatı, iptal, panoya + geçmiş | Testte | Pencere başlığı "SelectionWindow" → "Renk seçimi" |
| Global | Kısayol | Katmanı açar | Testte | |
| Tepsi | Sol tık / sağ tık menüsü → Çıkış | Pencere açılır / uygulama kapanır | Testte | Sol tık hiçbir şey yapmıyordu → pencereyi açar |
| Duman testi | Açılış | Gerçek %AppData% verisine dokunmaz | Düzeltildi | Önceden gerçek ayar klasörüyle açılıyordu |
