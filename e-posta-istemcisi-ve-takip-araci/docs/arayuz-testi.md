# Arayüz testi envanteri

Otomasyon: Playwright `_electron` (`e2e/ui.spec.ts` + `e2e/app.spec.ts`), derlenmiş uygulama, geçici veri klasörü (`EPOSTA_DATA_DIR`).
Yerel aç/kaydet diyalogları ana süreçte sahte yanıtlarla değiştirilir (gerçek pencere açılmaz); SMTP için süreç içi sahte sunucu, IMAP için kapalı port.
Girdiler CDP üzerinden gönderilir (gerçek fare/klavye yok). Çalıştırma: `.\run.ps1 -UiTest`. Son çalıştırma: 5/5 geçti (Electron 44.5.1).

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Karşılama | Esc (Başla ile aynı) | Kapanır, bir daha gösterilmez | Geçti | "Hesap ayarları" önceden onboarding'i kaydetmiyordu (düzeltildi) |
| Başlık çubuğu | Senkronize | Hesap yoksa anlaşılır mesaj | Geçti | Önceden "0 mesaj indirildi" diyordu |
| Başlık çubuğu | Ayarlar (dişli) | Ayarlar penceresi | Geçti | |
| Kenar çubuğu | Yeni Mail | Yeni mesaj penceresi | Geçti | |
| Kenar çubuğu | Klasörler (Gelen, Yıldızlı, Gönderilmiş, Taslaklar, Takip, Ertelenen, Arşiv, Çöp) | Liste değişir, aria-current, sayaç rozeti | Geçti | "Ertelenen" yeni; ertelenen mailler önceden hiçbir yerde görünmüyordu, sayaç hep 0'dı |
| Kenar çubuğu | Birleşik Gelen | Yalnızca 2+ hesapta görünür | Geçti | |
| Kenar çubuğu | Takip paneli öğesi | Maili kendi klasöründe açar | Geçti | Önceden klasör değişince başka mail açılıyordu (düzeltildi); gönderilenlerde alıcı adı gösterilir |
| Liste | Mail ara + `/` | Filtreler, eşleşme yoksa boş durum | Geçti | |
| Liste | Satır (tık / klavye odağında Enter) | Okuyucuda açar, okundu yapar | Geçti | Ekli satırların rozeti kırpılıyordu: satır yüksekliği artık ölçülüyor |
| Liste | Satır yıldızı | Yıldızlar, aria-pressed | Geçti | |
| Liste | Toplu seç / Seçimi kapat, satır onay kutuları | Seçim modu, onay kutusu adı mail konusunu içerir | Geçti | |
| Liste | Toplu: Okundu, Okunmadı, Yıldızla, Arşivle, Ertele, Sil | İşlem + "Geri al" | Geçti | Geri al yeni |
| Liste (dar) | Klasör seç, Yeni | Kompakt araç çubuğu | Geçti | %150 yakınlaştırma (yüksek DPI) ile test edildi, yatay taşma yok |
| Okuyucu | Yanıtla / İlet | Ön doldurulmuş pencere | Geçti | |
| Okuyucu | Yıldızla / Yıldızı kaldır | aria-pressed | Geçti | |
| Okuyucu | Ertele menüsü (bu akşam, yarın, gelecek hafta, özel tarih) | Ertelenen'e taşır, Esc menüyü kapatır | Geçti | 18:00 sonrası etiket "Yarın akşam" olur; Esc yeni |
| Okuyucu | Takip et / Takibi bırak | Takip klasörü + panel | Geçti | |
| Okuyucu | Arşivle / Okunmadı / Sil | İşlem + "Geri al" (Ctrl+Z) | Geçti | |
| Okuyucu | Gelen kutusuna taşı / Geri yükle / Kalıcı sil | Arşiv, Ertelenen ve Çöp'ten geri dönüş | Geçti | Yeni: önceden arşiv/çöpten geri almanın yolu yoktu |
| Okuyucu | HTML mail | Korumalı iframe, uzak görsel yüklenmez | Geçti | Koyu temada koyu zemin üstünde koyu metin görünüyordu (beyaz zemin) |
| Okuyucu (dar) | Gelen kutusuna dön | Kaplama okuyucuyu kapatır | Geçti | |
| Durum çubuğu | Geri al | Son işlemi geri alır | Geçti | Yeni |
| Yeni mesaj | Kime / Konu / Mesaj, açılışta Kime'ye odak | | Geçti | `r`/`f`/`c` tuşu açılan pencerenin alanına yazılıyordu (düzeltildi) |
| Yeni mesaj | Şablon seç | Konu + gövde doldurulur | Geçti | |
| Yeni mesaj | Okundu bildirimi, Yanıt takibi + süre | Onay kutuları yan yana, süre seçimi | Geçti | Onay kutuları etiketin üstünde ortalanıyordu (CSS düzeltildi) |
| Yeni mesaj | Ek ekle / ek kaldır (×) | Dosya listesi; iptal değiştirmez | Geçti | × düğmesine erişilebilir ad eklendi |
| Yeni mesaj | Gönder / Ctrl+Enter | Gönderir; hata pencerede, yazılan korunur | Geçti | Ctrl+Enter yeni |
| Yeni mesaj | Taslak kaydet / İptal / Esc / arka plan | Esc değişiklik varsa taslağa kaydeder; arka plan tıklaması kapatmaz | Geçti | Önceden arka plana tıklamak yazılanı siliyordu |
| Taslaklar | Taslak satırı | "Taslak düzenle" penceresi | Geçti | |
| Ayarlar | Sağlayıcı (Özel/Gmail/Outlook) | Sunucu/port doldurulur | Geçti | Seçicilere erişilebilir ad eklendi |
| Ayarlar | Hesap alanları, Şifre (kayıtlı ipucu) | Şifre arayüze geri gelmez | Geçti | `app.spec.ts` |
| Ayarlar | Bağlantıyı test et | IMAP + SMTP sonucu / eksik bilgi mesajı | Geçti | |
| Ayarlar | Google ile bağlan | Client ID yoksa hata | Geçti | Gerçek OAuth akışı otomatikleştirilmedi |
| Ayarlar | + Hesap ekle / Kaldır | | Geçti | Boş hesap kartı artık "hayalet hesap" olarak kaydedilmez |
| Ayarlar | Tema (Sistem/Açık/Koyu) | Anında uygulanır, kalıcı | Geçti | Yeni |
| Ayarlar | Önbellek, senkron aralığı, 5 onay kutusu | settings.json'a yazılır | Geçti | Etiketler alanlara bağlandı |
| Ayarlar | Tümünü okundu işaretle | | Geçti | |
| Ayarlar | Çöpü boşalt | İkinci tıkta kalıcı siler | Geçti | Onay yeni |
| Ayarlar | Şablonlar / Yardım / Hakkında | İlgili pencere | Geçti | |
| Ayarlar | Dışa aktar (iptal + kaydet) / İçe aktar (geçerli + bozuk) | JSON yedek; bozuk dosyada anlaşılır hata | Geçti | İçe aktarma artık "Ayarlar kaydedildi" demiyor |
| Ayarlar | Kaydet / Kapat / Esc / arka plan | Arka plan tıklaması kapatmaz | Geçti | |
| Şablonlar | + Yeni şablon, Vazgeç, Şablonu kaydet (boş ad pasif), Düzenle, Sil | | Geçti | Vazgeç ve boş ad kontrolü yeni |
| Yardım | F1, Tamam, Esc | | Geçti | |
| Hakkında | Sürüm, Kapat | | Geçti | |
| Kısayollar | j, k, Enter, r, f, e, u, #, s, c, /, Ctrl+Z, Esc, F1 | | Geçti | Esc artık tüm pencereleri kapatır (önceden Şablonlar/Hakkında/Karşılama kapanmıyordu) |
| Tüm pencereler | Erişilebilir ad | role=dialog + başlık | Geçti | Ortak `Modal` bileşeni |
