# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (pytest-qt, gerçek Windows pencereleri, `test/ui/`, 17 test). Örnek görseller
ve çıktı klasörü `tmp_path` altında; dosya diyalogları ve soru kutuları taklit edilir.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana pencere (boş) | Bırakma alanı, sayaç, Dönüştür düğmesi | "0 dosya", düğme pasif | Geçti | |
| Durum çubuğu | Kısayol ipuçları | Görünür | **Düzeltildi** | Kalıcı `showMessage("Hazır")` ipuçlarını gizliyordu |
| Araç çubuğu | `Ctrl+O`, "+ Ekle" | Dosya eklenir; tekrar / desteklenmeyen için mesaj | **Düzeltildi** | Hiçbir şey eklenmeyince geri bildirim yoktu |
| Araç çubuğu | "+ Klasör", `Ctrl+Shift+O` | Alt klasörlerle eklenir | **Eklendi** | Klasör yalnızca sürükle-bırakla eklenebiliyordu |
| Bırakma alanı | Tıklama, `Enter` / `Space` | Dosya diyaloğu | **Düzeltildi** | Odak alıyor ama klavyeyle çalışmıyordu |
| Pencere | Sürükle-bırak | Klasör / dosya eklenir; iş sürerken yok sayılır | **Düzeltildi** | İş sürerken bırakılan dosyalar kuyruğa giriyordu |
| Kenar çubuğu | Format açılır listesi | Codec paneli + kalite etkinliği değişir | Geçti | |
| Kenar çubuğu | WebP kayıpsız, kalite / method kaydırıcıları | Kalite pasif "—"; değerler seçeneklere yansır | Geçti | |
| Kenar çubuğu | Genişlik / yükseklik ön ayarları | Tekli seçim, satır boyut önizlemesi güncellenir | Geçti | |
| Kenar çubuğu | "…" çıktı klasörü | Yol alanı güncellenir | Geçti | |
| Kenar çubuğu | Üzerine yaz + orijinal hedef | Onay sorulur, "Hayır" hiçbir şey yazmaz | Geçti | |
| Arama | `Ctrl+F`, yazma, temizle | Filtre, "(N gösteriliyor)", "Sonuç bulunamadı" | Geçti | Temizle (×) düğmesi **eklendi** |
| Kuyruk | Satır tıklama, `Del` | Seçer, kaldırır | Geçti | |
| Kuyruk | Fare üzerine gel / çık | Vurgu çıkınca kalkar | **Düzeltildi** | Vurgu kalıcı kalıyordu |
| Kuyruk | Küçük resimler | Hızlı yeniden çizim | **Düzeltildi** | Her tuş vuruşunda tüm görseller tam boyutta yeniden okunuyordu |
| Dönüştürme | `Ctrl+Enter`, ilerleme, sonuç | Çıktılar oluşur, bozuk dosya "Hata" | Geçti | |
| Dönüştürme | Hataları tekrarla / Tamamlananları sil | Durum sıfırlanır / satırlar silinir | Geçti | |
| Dönüştürme | `Esc` / "■ İptal" (Hayır / Evet) | İptal; kalanlar "İptal" | Geçti | |
| Dönüştürme | İptal sorusu açıkken iş biterse | Çökme yok | **Düzeltildi** | `None.cancel()` → AttributeError |
| Kuyruk | Kuyruğu temizle | Onay; "Hayır" korur | Geçti | |
| Kapanış | Ayar kaydı | Son format kaydedilir | Geçti | |
| Erişilebilirlik | Tüm düğme / kaydırıcı / liste / alan | Erişilebilir ad | **Düzeltildi** | "…", ön ayarlar, kaydırıcılar, arama adsızdı; odak çerçevesi yoktu (**eklendi**) |
