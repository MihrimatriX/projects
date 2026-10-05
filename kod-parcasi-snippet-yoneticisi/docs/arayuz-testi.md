# Arayüz testi envanteri

Otomasyon: Playwright `_electron` (`e2e/ui.spec.ts`), derlenmiş uygulama, ayrı `--user-data-dir` (gerçek
`%AppData%\kod-parcasi-snippet-yoneticisi\snippets.json` dosyasına dokunulmaz), pano içeriği test sonunda geri yüklenir.
Yerel aç/kaydet diyalogları ana süreçte sahte yanıtlarla değiştirilir. Çalıştırma: `.\run.ps1 -UiTest`.
Son çalıştırma: 3/3 geçti (Electron 44.5.1).

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana pencere (boş) | "İlk snippet'inizi oluşturun" + Boş snippet | Yeni snippet oluşturulup seçilir | Geçti | |
| Araç çubuğu | Snippet ara (Ctrl+F) | Başlık/kod/dil/klasör/etiket, Türkçe harf duyarsız; boş sonuç mesajı | Geçti | Ctrl+F yeni |
| Araç çubuğu | Alt+Shift+S rozeti | Kısayol kaydedilemezse ⚠ ve açıklama | Geçti | Önceden yalnızca konsola yazılıyordu |
| Araç çubuğu | Palet | Arama paletini açar | Geçti | Yeni düğme (kısayol çakışırsa da erişilebilir) |
| Araç çubuğu | Yeni snippet (Ctrl+N) | Oluşturur; kaydedilmemiş değişiklik varsa sorar | Geçti | Ctrl+N yeni |
| Araç çubuğu | Import / Export (Ctrl+E) | Modal açılır | Geçti | |
| Kenar çubuğu | Klasörler (Tümü / klasör) | Listeyi süzer | Geçti | |
| Kenar çubuğu | Etiket filtresi (Tümü / #etiket) | Listeyi süzer | Geçti | |
| Liste | Satır tıklama | Seçer; kaydedilmemiş değişiklik onayı reddedilirse seçim kalır | Geçti | |
| Liste | Yukarı / Aşağı / Home / End | Seçimi değiştirir, odak satıra gider | Geçti | Yeni (önceden klavyeyle gezilemiyordu) |
| Editör | Başlık, etiketler, dil, klasör, açıklama, kod | Değişiklik kirli işaretini gösterir; kaydedilince alanlar normalize edilir | Geçti | |
| Editör | Kopyala | Yer tutucular genişler, lastUsedAt güncellenir, bildirim | Geçti | |
| Editör | Kaydet / Ctrl+S | Yalnızca değişiklik varken etkin | Geçti | |
| Editör | Çoğalt | "(kopya)" oluşturur | Geçti | |
| Editör | Sil | Onay; vazgeçilirse silinmez | Geçti | |
| Import / Export | ✕, İptal, Esc, arka plan tıklaması | Modal kapanır | Geçti | Esc yeni |
| Import / Export | Import / Export sekmeleri | aria-selected değişir | Geçti | |
| Export | Sayılar + Dışa aktar | Snippet/etiket/klasör sayısı; iptal ve kayıt bildirimi | Geçti | Bildirim modal kapanınca kayboluyordu (düzeltildi) |
| Import | JSON dosyası seç | Doğrulama özeti; var olan id atlanır | Geçti | Eklenen sayı bildirimi modal kapanınca kayboluyordu (düzeltildi) |
| Import | Sürükle-bırak | Özet + içe aktarma | Geçti | Etiketsiz kayıtta "n.tags is not iterable" hatası (düzeltildi); içerik artık yoldan değil metinden aktarılır |
| Import | Geçersiz JSON | "Import hatası" kutusu | Geçti | |
| Import | Dosya seçmeden Import et | Yerel diyalog; iptalde "Yeni snippet eklenmedi" | Geçti | |
| Palet | Boş sorgu | Son kullanılanlar (saat ikonu) | Geçti | |
| Palet | Arama + Yukarı/Aşağı | aria-selected değişir | Geçti | |
| Palet | Enter | Güncel sorgunun sonucu kopyalanır, palet gizlenir | Geçti | Hızlı yazıp Enter eski sonucu kopyalıyordu (düzeltildi) |
| Palet | Satıra tıklama | Tıklanan satır kopyalanır | Geçti | Eski seçili satır kopyalanabiliyordu (düzeltildi) |
| Palet | Ctrl+Enter | Ana pencerede snippet seçilir | Geçti | |
| Palet | Esc | Gizlenir | Geçti | |
| Palet | Sonuç yok → "… adıyla yeni snippet oluştur" | Sorgu başlıklı snippet oluşur, ana pencerede açılır | Geçti | Önceden yalnızca ana pencereyi açıyordu |
| Global | Alt+Shift+S | Paleti açar | Otomatik test yok | Gerçek global klavye girdisi gerektirir (paylaşılan masaüstü); aynı pencereyi açan Palet düğmesi test edilir |
