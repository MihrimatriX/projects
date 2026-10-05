# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (pytest-qt, gerçek Windows pencereleri, `tests/ui/`, 23 test).
Testler geçici veri klasörü + demo klasörüyle çalışır; masaüstü ortak kilidi (`..\.gui.lock`) test oturumu boyunca tutulur.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Arama paleti | Açılış (`present`) | Boş durum "Aramak için yazmaya başlayın", kök özeti `~/Projeler` | Geçti | |
| Arama paleti | Arama kutusu (yazma) | 200 ms sonra sonuç satırları + "N sonuç" | Geçti | |
| Arama paleti | Sonuç satırı dosya adı | Ad satırı tam yükseklikte görünür | **Düzeltildi** | Düzen boşlukları adı 7 px'e kırpıyordu (yalnız yol görünüyordu) |
| Arama paleti | `↓` / `↑` | Seçim değişir, vurgulanır | Geçti | |
| Arama paleti | `Enter` | Seçili dosya açılır, palet kapanır | Geçti | |
| Arama paleti | `Ctrl+Enter` | Klasörde göster | Geçti | |
| Arama paleti | `Ctrl+Shift+C` | Tam yol panoda, "Yol kopyalandı" | **Düzeltildi** | Geri yükleme zamanlayıcısı kapanmış pencerede çöküyordu |
| Arama paleti | Satıra tık / çift tık | Seç / aç | Geçti | |
| Arama paleti | Satıra sağ tık | Aç · Klasörde göster · Yolu kopyala menüsü | **Eklendi** | |
| Arama paleti | Filtre çipleri (fare) | Tek çip etkin, sonuçlar süzülür | Geçti | |
| Arama paleti | `Ctrl+1`…`Ctrl+4` | Tümü/Belgeler/Kod/Resimler | **Eklendi** | Çip ipuçlarında yazıyor |
| Arama paleti | Sonuç yok | "Sonuç bulunamadı" | Geçti | |
| Arama paleti | `Esc` | Metin varsa temizler, boşsa kapatır | Geçti | |
| Arama paleti | Boş kutuda `↑` | Son aramayı getirir; son aramalar listelenir | Geçti | |
| Arama paleti | `&`, `<` içeren dosya adı | Düz metin gösterilir | **Düzeltildi** | Ad RichText olarak yorumlanıyordu |
| Arama paleti | Arama hatası | Kırmızı rozet + "Yeniden dene" çalışır | **Düzeltildi** | Düğme hiçbir yere bağlı değildi |
| Arama paleti | Ayarlar düğmesi / `Ctrl+,` | İndeks ayarları açılır | Geçti | Düğmeye erişilebilir ad eklendi |
| Arama paleti | Panel dışına tık | Palet kapanır | Geçti | |
| Arama paleti | `Ctrl+Space` (toggle) | Aç / kapat | Geçti | Genel kısayolun kendisi (RegisterHotKey) elle denenir |
| İndeks ayarları | Klasör satırları | `~/...` kısa yol, ipucunda tam yol | **Düzeltildi** | Her zaman "0 dosya (yaklaşık)" yazan sahte sayaç kaldırıldı |
| İndeks ayarları | Bulunamayan klasör | "(bulunamadı)" uyarısı | **Eklendi** | |
| İndeks ayarları | + Dizin ekle | Klasör eklenir, aynı klasör iki kez eklenmez | Geçti | |
| İndeks ayarları | Kaldır | Klasör çıkar; son klasörde uyarı | Geçti | Düğme adı "Kaldır: <klasör>" |
| İndeks ayarları | Onay kutuları + saat | Kaydet ile kalıcı | Geçti | Hepsine erişilebilir ad + odak çerçevesi eklendi |
| İndeks ayarları | Hariç tutma desenleri | Boş satırlar atılır, kırpılır | Geçti | |
| İndeks ayarları | İptal / ✕ / `Esc` | Kaydetmeden kapanır | Geçti | ✕ düğmesine "Kapat" adı eklendi |
| İndeks ayarları | Yeniden indeksle | İlerleme, bitince bilgi; düğme iş sürerken devre dışı | **Düzeltildi** | Çift tık iki indeksleyiciyi aynı anda başlatıyordu |
| İndeks ayarları | İndeksleme sürerken kapatma | Çökme yok, iş iptal edilir | **Düzeltildi** | Çalışan QThread yok ediliyordu |
| İndeks ayarları | Arama geçmişi → Temizle | "0 sorgu" | Geçti | |
| İndeks ayarları | İndeksi dışa / içe aktar | Dosya yazılır / onayla geri yüklenir | Geçti | |
| İndeks ayarları | Satır ayraçları | Yalnızca satır altında çizgi | **Düzeltildi** | Çizgi her etiketin altına sızıyordu |
| Tepsi menüsü | Aramayı aç · İndeks ayarları · Yeniden indeksle · Çıkış | Eylemler tetiklenir | Geçti | |
| Tepsi menüsü | Durum satırı | Hazır / Taranıyor / İndeks hatası | Geçti | Zamanlanmış indeks hatası artık palet rozetinde de görünür |
