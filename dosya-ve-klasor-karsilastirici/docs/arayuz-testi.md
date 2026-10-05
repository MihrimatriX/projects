# Arayüz testi envanteri

Otomasyon: Playwright `_electron` (`e2e/ui.spec.ts`), derlenmiş uygulama, geçici `%LocalAppData%` / `%AppData%`.
Yerel aç/kaydet diyalogları ve `shell.showItemInFolder` ana süreçte sahte yanıtlarla değiştirilir (gerçek pencere açılmaz).
Çalıştırma: `.\run.ps1 -UiTest`. Son çalıştırma: 3/3 geçti (Electron 44.5.1).

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Karşılama | Sürükle-bırak bölgesi | dragover'da vurgulanır, dragleave'de söner | Geçti | Gerçek dosya bırakma (OS) otomatikleştirilmedi |
| Karşılama | Son karşılaştırmalar düğmesi | Çifti yükler ve karşılaştırır | Geçti | |
| Araç çubuğu | Sol / Sağ yol kutusu | Yazılabilir/yapıştırılabilir, Enter karşılaştırır, tırnaklar temizlenir | Geçti | Önceden salt okunurdu (düzeltildi) |
| Araç çubuğu | Sol / Sağ "yolu seç" (klasör ikonu) | Diyalogdan yolu alır; iptal yolu değiştirmez | Geçti | Yeni düğme |
| Araç çubuğu | Yolları değiştir | Sol/sağ yer değiştirir, bildirim | Geçti | |
| Araç çubuğu | Karşılaştır / F5 | Boş yol ve olmayan yol için anlaşılır hata | Geçti | IPC "Error invoking remote method" öneki temizlendi |
| Araç çubuğu | +/− özeti | Eklenen/silinen satır sayısı | Geçti | |
| Araç çubuğu | Birleştir → / ← Birleştir | Hedefe kopyalar, `.bak` alır, tek taraflı dosyada tek yön | Geçti | |
| Araç çubuğu | Git'ten Yükle | Diyalog açılır | Geçti | |
| Araç çubuğu | Patch Dışa Aktar | Unified patch yazar; binary / tek taraflıda pasif; iptal güvenli | Geçti | |
| Araç çubuğu | Klasör ağacını aç/kapat | Dar pencerede (≤900 px) görünür, aria-expanded değişir | Geçti | |
| Hata bandı | ✕ Hatayı kapat | Bandı gizler | Geçti | Yeni; başarılı git içe aktarma eski hatayı da temizler |
| Görünüm sekmeleri | Yan Yana / Satır İçi | Monaco modu değişir, aria-selected | Geçti | Etkin sekme hover'da sönük görünüyordu (düzeltildi) |
| Görünüm sekmeleri | 3-Yönlü Birleştir | Base yolu yoksa pasif | Geçti | |
| Görünüm sekmeleri | Hex Görünüm | Yalnızca binary'de etkin, binary'de otomatik seçilir | Geçti | |
| Diff paneli | ↑ Önceki fark / ↓ Sonraki fark, Alt+↑ / Alt+↓ | İmleç önceki/sonraki fark satırına gider | Geçti | Yeni özellik |
| Hex paneli | Sol/Sağ başlık | Bayt boyutları | Geçti | |
| 3-yönlü | Sol Al / Sağ Al / Base / Her İkisi | Seçim aria-pressed ile görünür, bekleyen sayısı düşer | Geçti | Seçili düğme vurgusu eklendi |
| 3-yönlü | Birleştirilmiş Dosyayı Kaydet | Tüm çakışmalar çözülmeden pasif; çözümleri dosyaya yazar | Geçti | |
| Klasör ağacı | Dosya ara | Büyük/küçük harf duyarsız; eşleşme yoksa boş durum metni | Geçti | |
| Klasör ağacı | Aynı dosyaları da göster | Aynı dosyalar listeye eklenir/çıkar | Geçti | |
| Klasör ağacı | Klasör satırı (tık / Enter) | Açılır/kapanır, aria-expanded | Geçti | Kök klasörler kapanmıyordu (düzeltildi) |
| Klasör ağacı | Dosya satırı (tık / Enter) | Dosya farkını açar | Geçti | |
| Klasör ağacı | ↗ Klasörde göster | Gezginde gösterir; yalnız-sağ dosyada yok | Geçti | Erişilebilir ad eklendi |
| Durum çubuğu | Sol/Sağ sayıları, seçili dosya | Doğru | Geçti | |
| Durum çubuğu | Git ← / → | Çok dosyalı diff'te gezinir, uçlarda pasif | Geçti | Erişilebilir ad eklendi |
| Git diyaloğu | İçe Aktar / İptal / metin | Boşken pasif; geçersiz metinde hata | Geçti | Düz metin "unknown" dosya olarak kabul ediliyordu (düzeltildi) |
| Yardım | F1, Tamam, Esc | Açılır/kapanır, kısayol tablosu | Geçti | Esc eklendi |
| Ayarlar | Ctrl+,, ✕, "← Karşılaştırmaya dön", Esc | Açılır/kapanır | Geçti | Esc odak nerede olursa olsun çalışır |
| Ayarlar > Genel | Tema (Koyu/Açık) | Arayüz + Monaco teması değişir, kalıcı | Geçti | Sahte "Koyu tema" anahtarı yerine gerçek seçim |
| Ayarlar > Genel | .bak yedekleme anahtarı | Değer kaydedilir | Geçti | Eski değeri kaydediyordu (düzeltildi) |
| Ayarlar > Genel | Önbelleği temizle | Hash önbellek klasörü silinir, bildirim | Geçti | Hiçbir şey silmiyordu (düzeltildi); sahte "Hash önbellek" anahtarı kaldırıldı |
| Ayarlar > Diff | Limitler (salt okunur) | 4 MB / 256 KB | Geçti | Erişilebilir ad eklendi |
| Ayarlar > Diff | Varsayılan görünüm | Kaydedilir | Geçti | Eski değeri kaydediyordu (düzeltildi) |
| Ayarlar > Diff | Base yolu | Odaktan çıkınca kırpılıp kaydedilir | Geçti | |
| Ayarlar > Son Çiftler | Liste / boş durum / Listeyi Temizle | Tıklayınca karşılaştırır ve kapanır | Geçti | |
| Ayarlar > Gitignore | Filtre desenleri + Kaydet, .gitignore anahtarı | Boş satırlar atılır, kaydedilir | Geçti | |
