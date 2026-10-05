# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (pytest-qt, gerçek Windows pencereleri, `tests/ui/`, 19 test).
Testler `TEKRARLANAN_DATA_DIR` geçici klasörü, ayrı IPC kanalı ve demo dosyalarıyla çalışır; silme testinde
Geri Dönüşüm Kutusu yerine sahte çöp işlevi kullanılır. Masaüstü ortak kilidi (`..\.gui.lock`) test oturumu boyunca tutulur.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana pencere (boş) | "Klasör seç (Ctrl+O)" / `Ctrl+O` | Kök eklenir, çalışma sayfasına geçilir, ayara yazılır | Geçti | Aynı klasör iki kez eklenmez |
| Ana pencere (boş) | İpucu metni | Kullanıcı dilinde | **Düzeltildi** | "IPC handoff" geliştirici jargonu kaldırıldı |
| Kenar çubuğu | Kökü kaldır (düğme / sağ tık / `Delete`) | Kök listeden çıkar | **Eklendi** | Önceden kökü kaldırmanın arayüzde hiçbir yolu yoktu |
| Kenar çubuğu | Sürükle-bırak | Yalnızca var olan klasörler eklenir | Geçti | |
| Araç çubuğu | Yeniden tara / `F5` | Tarama, ilerleme paneli, sonuçlar | Geçti | |
| Tarama paneli | Yüzde göstergesi | Gerçek veri | **Düzeltildi** | Dosya sayısından uydurulan sahte "%" kaldırıldı |
| Tarama paneli | `Esc` | Taramayı iptal eder; tarama yokken zararsız | Geçti | |
| Kart görünümü | Grup başlığı (tık / `Space` / `Enter`) | Aç / kapat | **Düzeltildi** | Klavyeyle açılamıyordu; odak çerçevesi eklendi |
| Kart görünümü | Kopya onay kutusu | İşaret + "Silinecek/Kopya" etiketi + seçim özeti güncellenir | **Düzeltildi** | Etiket güncellenmiyordu; kutulara erişilebilir ad eklendi |
| Ağaç görünümü (80+ grup) | Onay kutuları | Yalnızca kopyalar işaretlenebilir | **Düzeltildi** | Bayraklar uygulanmıyordu; asıl dosya satırı da işaretlenebilir durumdaydı |
| Kompakt liste (eşik üstü) | Çift tık / `Enter` | Grup detayı açılır | **Düzeltildi** | Yalnız çift tık çalışıyordu |
| Grup detayı | Onay kutuları, Göster, Aç, `Esc`/✕ | İşaretler her kapanışta uygulanır | **Düzeltildi** | Esc/✕ ile değişiklikler kayboluyordu |
| Filtre | `Ctrl+F`, yazma, temizle düğmesi | Gruplar süzülür | **Eklendi** | `Ctrl+F` ve temizle (×) düğmesi |
| Sıralama | İsraf / Kopya / Boyut / Yol | Seçim kalıcı | Geçti | |
| Eylem çubuğu | Öneriyi uygula · Tümünü seç | İşaretler | Geçti | Sonuç yokken bilgi mesajı |
| Eylem çubuğu | Seçilileri sil / `Delete` | Onay diyaloğu → çöp kutusu → liste güncellenir | Geçti | |
| Silme onayı | "Kalıcı sil" | Düğme "Kalıcı olarak sil", metin güncellenir | **Düzeltildi** | Kalıcı seçiliyken "Çöp kutusuna taşı" yazıyordu |
| Silme onayı | İptal / `Esc` | Hiçbir dosya silinmez | Geçti | |
| Dosya menüsü | JSON / CSV / HTML dışa aktar (`Ctrl+E`, `Ctrl+Shift+E`, `Ctrl+Shift+H`) | Dosyalar yazılır, son klasör hatırlanır | Geçti | |
| Araçlar menüsü | İşaretleri temizle / tersine çevir | İşaretler değişir | Geçti | |
| Araçlar menüsü | Oturumu kaydet / yükle (bozuk dosya dahil) | Kayıt; bozuk dosyada hata mesajı | Geçti | |
| Araçlar menüsü | Tarama geçmişi | Son tarama listelenir | Geçti | |
| Araçlar menüsü | Önbelleği temizle | "temizlendi" / "zaten boş" | Geçti | |
| Ayarlar (`Ctrl+,`) | Tüm alanlar, Tamam / İptal | Tamam kaydeder, korunan klasör işaretleri yeniler; İptal değiştirmez | Geçti | |
| Yardım (`F1`) | Kısayol tablosu | Tüm kısayollar | **Düzeltildi** | Delete/Esc/Ctrl+F eksikti |
| Hakkında | Kapat | Kapanır | Geçti | |
| Sayfalama | "Daha fazla grup" | Sonraki sayfa | Geçti | |
| IPC handoff | `{"action":"show"}` / kökler | Pencere öne gelir / kökler eklenir | Geçti | |
| Kapatma | Pencere boyutu | Ayara kaydedilir | Geçti | |
| Tepsi | Göster · Tara · Çıkış | — | Elle | `main.py` içinde kurulur; exe açılışında doğrulandı |
