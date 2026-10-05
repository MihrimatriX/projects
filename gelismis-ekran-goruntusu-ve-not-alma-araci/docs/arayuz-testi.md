# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (FlaUI/UIA3, geçici `EKRAN_GORUNTUSU_DATA_DIR`). Ekran kopyası ve gerçek fare/klavye
adımları ortak `.gui.lock` içinde; fare yalnızca hedef noktada düzenleyici en üstteyse gönderilir.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana | Boş durum | Kısayol ipucu, Geçmişi temizle devre dışı | Geçti | İpucu artık seçili kısayolu gösterir |
| Ana | Görsel aç → Aç diyaloğu | Düzenleyici açılır (900 × 220) | Geçti | Yeni |
| Düzenleyici | Araçlar (5) | Tek seçimli, `1`–`5` tuşları | Geçti | "1".."5" yazan düğmeler etiketlendi, RadioButton |
| Düzenleyici | Çizim + `Ctrl+Z` | Geri al etkin/devre dışı | Geçti | |
| Düzenleyici | OCR | Metin (dil paketi varsa) / "Metin bulunamadı" | Geçti | |
| Düzenleyici | `Esc` (işaretleme varken) | Kaydedilmedi onayı; Hayır → açık kalır | Geçti | Çizimden sonra Esc hiç çalışmıyordu (düzeltildi); onay yeni |
| Düzenleyici | Kaydet / `Ctrl+S` | Geçmişe eklenir, pencere kapanır | Geçti | Kayıt sürerken ikinci kayıt engellendi |
| Ana | Detay paneli | Seçili kaydın önizlemesi + OCR metni | Geçti | Görünürlük dönüştürücüsü tersti: detay hiç görünmüyordu |
| Ana | Düzenle | Kayıt düzenleyicide açılır | Geçti | Yeni |
| Ana | Arama / boş sonuç | Eşleşme yok + Aramayı temizle | Geçti | Yer tutucu ve boş durum yeni |
| Ana | Sil (MessageBox Hayır/Evet) | Kayıt + PNG silinir | Geçti | |
| Ana | Geçmişi temizle | Liste ve dosyalar boş | Geçti | |
| Ayarlar | Geçersiz şablon / Kaydet / Gözat / Varsayılana dön / Kapat | Uyarı, kalıcılık, iptal, sıfırlama | Geçti | Kısayol ve geçmiş sınırı seçimi yeni |
| Yakalama | Tam ekran + Yakala | Düzenleyici öne gelir | Geçti | Ana pencere düzenleyicinin üstüne geliyordu (düzeltildi) |
| Yakalama | Global kısayol, `Esc` | Açılır / iptal, ana pencere döner | Geçti | |
| Ana | `Ctrl+F`, `Esc`, `Ctrl+O` | Arama, temizleme, Aç diyaloğu | Geçti | |
| Tümü | Koyu tema ComboBox, erişilebilir adlar | Koyu, adlandırılmış | Gözle | Başlık çubuğu düğmelerine ad eklendi |
