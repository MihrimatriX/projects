# Arayüz testi envanteri

Otomasyon: Playwright `_electron` (`e2e/ui.spec.ts`, `e2e/app.spec.ts`), derlenmiş uygulama, geçici veri klasörü (`HOOKYEREL_DATA_DIR`).
Kaydet diyaloğu ana süreçte, pano sayfa içinde sahte (sistem panosuna yazılmaz). Çalıştırma: `.\run.ps1 -UiTest`. Son çalıştırma: 4/4 geçti (Electron 44.5.1).

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Kenar çubuğu | Port, Durdur / Sunucuyu başlat | Çalışırken port kilitli; dolu portta sonraki port | Geçti | |
| Kenar çubuğu | + Endpoint oluştur, Ctrl+N → pencere (İptal, ×, Esc, oluştur) | Yeni endpoint seçilir | Geçti | |
| Kenar çubuğu | Endpoint kartı, URL kopyala, Ctrl+L | Seçim, URL panoya | Geçti | Kopyala düğmesi kart düğmesinin içindeydi (iç içe etkileşim) — ayrıldı, adına slug eklendi |
| Kenar çubuğu | Endpoint sil (×) | İkinci tıkta endpoint + istekleri silinir; son endpoint silinemez | Geçti | Onay yeni (önceden tek tıkla tüm istekler gidiyordu) |
| Kenar çubuğu | Mock kuralları, Ayarlar | Pencereler | Geçti | |
| Filtre | Arama kutusu (f, /), POST/GET/PUT/PATCH/DELETE çipleri, Filtreyi temizle | Liste süzülür, çipler aria-pressed | Geçti | Yer tutucu kırpılıyordu (kutu tam satır); çiplere aria-pressed; boş sonuçta "Filtreyle eşleşen istek yok" |
| Liste | Satır tık, ↑ ↓ (başa/sona sarar), yeni istek otomatik seçilir | | Geçti | Listeye erişilebilir ad eklendi |
| Liste | Tüm istekleri sil | İkinci tıkta silinir | Geçti | Önceden filtre "Temizle" ile aynı adlı, onaysız tek tık |
| Detay | Replay (düğme + r), curl (düğme + c), İsteği sil | | Geçti | |
| Detay | İmza doğrulama / Headers / Body bölümleri | Açılır-kapanır, aria-expanded | Geçti | aria-expanded yeni |
| Detay | İmza preset + secret + Doğrula | Geçerli / başarısız rozeti | Geçti | |
| Mock kuralları | Method, path regex, durum, gövde, Kural ekle, kural sil, Kapat, Esc | Kural uygulanır / kaldırılır | Geçti | Boş durum metni ve sil düğmesine kural adı eklendi |
| Ayarlar | Varsayılan port | 1024-65535 dışı Kaydet'i kapatır | Geçti | Önceden 80 gibi değerler kaydediliyordu |
| Ayarlar | Açılışta başlat, Secret maskeleme, body boyutu, retention, Kaydet, İptal, Kapat | Kalıcı / iptalde atılır | Geçti | Seçicilere erişilebilir ad eklendi |
| Ayarlar | Günlüğü dışa aktar (iptal + kaydet) | JSON dosyası | Geçti | |
| Kısayollar | ?, ×, Esc | | Geçti | Pencere açıkken r/c/oklar arkadaki listede çalışıyordu (düzeltildi) |
| Dar pencere / %150 | Endpoint'ler çekmecesi | Açılır, seçim ve Esc kapatır, yatay taşma yok | Geçti | |
