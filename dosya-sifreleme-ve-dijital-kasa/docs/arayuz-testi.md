# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (FlaUI/UIA3, `DosyaSifreleme.Tests\UiTests.cs`). Her test gerçek exe'yi geçici ayar
klasörü (`DOSYA_SIFRELEME_DATA_DIR`) ve geçici kasayla, atılabilir parolalarla açar. Ortak dosya diyalogları ve
MessageBox'lar UIA desenleriyle sürülür; gerçek klavye girdisi yalnızca kısayol adımlarında ve ortak `.gui.lock`
kilidi içinde gönderilir.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Giriş | İlk açılış modu | Hatırlanan kasa yoksa "Kasayı Oluştur ve Aç" | Geçti | Eskiden her zaman "Kasa Aç" ile başlıyordu |
| Giriş | Mod değiştir bağlantısı | Oluştur ⇄ Aç metinleri değişir | Geçti | |
| Giriş | Kasa konumu kutusu | Yazılabilir; boş → "Lütfen bir kasa klasörü seçin.", göreli yol → tam yol hatası | Geçti | Eskiden salt okunurdu (yol yapıştırılamıyordu) |
| Giriş | `Seç` → klasör diyaloğu | Seçilen yol kutuya gelir | Geçti | Diyalog artık ana pencereye bağlı |
| Giriş | Parola kutusu | < 6 karakter → hata; güç çubuğu "Çok güçlü" | Geçti | Güç çubuğu/etiketi yalnız oluşturma modunda |
| Giriş | Göster/gizle (👁) | Düz metin kutusu parolayı gösterir/gizler | Geçti | Erişilebilir ad eklendi |
| Giriş | Kasa metin kutuları | Metin dikeyde kırpılmadan görünür | Geçti | Eskiden üst yarısı kesiliyordu (şablon düzeltildi) |
| Giriş | Oluştur | `vault.db` oluşur, pano açılır | Geçti | |
| Giriş | Var olan kasanın üzerine oluştur | "Bu klasörde zaten bir kasa bulunuyor." | Geçti | |
| Giriş | Kasa olmayan klasörü aç | "Seçilen klasörde geçerli bir kasa bulunamadı." | Geçti | |
| Giriş | Yanlış parola | "Geçersiz parola veya bozuk kasa dosyası.", pano açılmaz | Geçti | |
| Giriş | `Enter` | Kasayı oluşturur/açar | Geçti | Gerçek tuş, kilit içinde |
| Giriş | Yeniden başlatma | Son kasa yolu dolu, "Kasa Aç" modunda, parola kutusu odakta | Geçti | Yeni özellik |
| Pano | Boş durum | "Kasa boş"; Tümünü çıkar devre dışı | Geçti | Tümünü çıkar 0 dosyada da etkin görünüyordu (dönüştürücü düzeltildi) |
| Pano | `+ Ekle` → Aç diyaloğu | Dosya listeye eklenir, orijinal kalır, durum "Eklendi: …" | Geçti | Şifreleme artık arka planda |
| Pano | Ekle → İptal | Değişiklik yok | Geçti | |
| Pano | Ekledikten sonra orijinali sil | Orijinal silinir, durum "Taşındı…", `.enc` içinde düz metin yok | Geçti | Onay kutusu koyu temaya uyarlandı |
| Pano | Arama kutusu | `ŞİFRE` → "şifre-notları.md" (Türkçe duyarsız) | Geçti | Yer tutucu metin eklendi (eskiden görünmüyordu) |
| Pano | Eşleşme yok | "Eşleşen dosya yok" + "Aramayı temizle" | Geçti | Yeni boş durum |
| Pano | Liste | Dosya adları okunur | Geçti | Ad metni siyah-üstü-koyuydu (görünmüyordu), düzeltildi; UIA adı artık dosya adı |
| Pano | Çıkar (araç çubuğu) | Seçim yokken devre dışı; onay katmanı → İptal kapatır | Geçti | |
| Pano | Çıkar (satır) → Kaydet diyaloğu | Dosya son çıkarma klasörüne deşifre edilir | Geçti | Son çıkarma klasörü hatırlanır |
| Pano | Tümünü çıkar → klasör diyaloğu | Tüm dosyalar klasöre, "2 dosya çıkarıldı" | Geçti | Yeni özellik |
| Pano | Bilgi → MessageBox | Ad/boyut/uzantı/tarih | Geçti | |
| Pano | Sil → MessageBox | Hayır: kalır; Evet: kayıt + `.enc` silinir | Geçti | |
| Pano | Otomatik kilit kutusu | 15 dk seçimi `settings.json`'a yazılır, geri sayım güncellenir, yeniden açılışta korunur | Geçti | Yeni ayar; koyu ComboBox şablonu |
| Pano | Kilitle | Giriş ekranı, "Kasa kilitlendi.", parola kutusu boş | Geçti | Kilit nedeni eskiden atılan panoya yazılıyordu (görünmüyordu) |
| Pano | Otomatik kilit | Süre dolunca giriş ekranı + neden | Geçti | `DOSYA_SIFRELEME_AUTOLOCK_SECONDS=4` |
| Pano | `Ctrl+F`, `Esc` | Aramaya odaklanır / temizler | Geçti | Odak yokken çalışmıyordu (pencere düzeyine taşındı) |
| Pano | `↓`, `Enter` | Listeye geçer, çıkarma onayı açılır | Geçti | Yeni kısayollar |
| Pano | `Esc` (onay açıkken) | Onay katmanı kapanır | Geçti | Yeni |
| Pano | `Delete` | Silme onayı açılır | Geçti | |
| Pano | `Ctrl+O` | Ekleme diyaloğu açılır | Geçti | |
| Pano | `Ctrl+L` | Kilitler | Geçti | |
| Pano | Sürükle-bırak | Dosyalar eklenir, klasörler atlanır (bilgi mesajı) | Elle | UIA ile sürükle-bırak gönderilemez |
| Tümü | Yüksek DPI / koyu tema | Tek koyu tema; ölçeklemede WPF vektörel | Gözle | `docs/ekran*.png` %100 ölçekte |
