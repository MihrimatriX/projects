# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (FlaUI/UIA3, 4 test). Uygulama gecici veri klasoru (`CLIPBOARD_GECMISI_DATA_DIR`) ve
test modu (`CLIPBOARD_GECMISI_TEST=1`) ile acilir; kullanicinin pano icerigi test oncesi saklanir, sonra geri yazilir.
Gercek klavye/fare adimlari ortak `.gui.lock` icinde.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Panel | Boş durum | "Henüz kopyalanan öğe yok" | Geçti | |
| Panel | Pano yakalama | Metin, URL, kod, e-posta, görsel satırları; satır adı = önizleme | Geçti | Satır UIA adı sınıf adıydı → düzeltildi. Görsel her kopyada **2 kez** kaydediliyordu → içerik özetli dosya adı |
| Panel | Arama / boş sonuç | `rapor` → 1, eşleşme yok → "Eşleşme bulunamadı" | Geçti | |
| Panel | Filtre çipleri | URL 1, Kod 1, Görsel 1, Metin 2, Tümü 5 | Geçti | |
| Panel | Çoklu seçim (Shift+↓) | "2 seçili" çubuğu, Stack'e ekle → Stack 2 | Geçti | İki yönlü SelectedItem bağlaması hızlı çoklu seçimi tek öğeye indiriyordu → tek yönlü |
| Panel | Toplu sil | Onay Hayır = korur, Evet = siler + "Ctrl+Z geri al" | Geçti | |
| Panel | Enter / Ctrl+P / Delete / Ctrl+Z | Panoya al, sabitle, sil, geri al (sabitleme korunur) | Geçti | Enter/Ctrl+P sonrası seçim kayboluyordu → korunur |
| Panel | Ctrl+F, ↓, F1, Esc | Aramaya odak, listeye geç, yardım, gizle | Geçti | |
| Global | Panel / stack kısayolu | Gizli paneli açar (arama odaklı); stack sırayla panoya yazar | Geçti | Testte F9/F10 kısayolları |
| Menü (⋯) | Yardım | Ayarlardaki kısayolları gösterir | Geçti | Sabit "Ctrl+Alt+V" yazıyordu → ayardan |
| Menü | Hakkında → Güncellemeleri kontrol et | "Güncel sürüm" mesajı, kontrol zamanı yazılır | Geçti | Otomatik kontrol kapalıyken elle kontrol hiç bakmıyordu → düzeltildi |
| Menü | Ayarlar | Geçersiz limit / aynı kısayol uyarısı, Kaydet yazar, İptal yazmaz | Geçti | Kaydet/İptal küçük ekranda görünmüyordu → sabit alt çubuk |
| Menü | Yedekle | Kaydet diyaloğu → "3 öğe dışa aktarıldı" | Geçti | Test modunda diyalog veri klasöründe açılır |
| Menü | İçe aktar | Aç diyaloğu veri klasöründe, İptal etkisiz | Geçti | Birleştirme akışı birim testinde |
| Menü | Geçmişi temizle | Onay Hayır = korur, Evet = siler | Geçti | Onaysız siliyordu → onay eklendi |
| Menü | Stack'i temizle / Çıkış | Stack 0 / süreç kapanır | Geçti | |
| Tek örnek | Aynı veriyle 2. örnek | "Zaten açık" + çıkış | Geçti | Test örneği kullanıcının örneğiyle aynı kilidi paylaşıyordu → veri klasörüne göre |
| Şifreleme | Ayarlar → parola belirle | Boş parola uyarısı, "Şifreli" rozeti | Geçti | |
| Şifreleme | Kilitle / yanlış / doğru parola | Liste gizlenir, "Parola hatalı", kilit açılır | Geçti | Şifreli modda aynı metin her kopyada yeni kayıt açıyordu → çözülerek tekilleştirme |
| İlk açılış | Hoş geldiniz | Ayarlardaki kısayol, Başla → FirstRunCompleted | Geçti | |
| Tepsi | Sol tık (UIA Invoke) | Paneli açar | Geçti | Sol tık bir şey yapmıyordu → panel açar |
| Tepsi | Sağ tık menüsü | Menü açılır, Hakkında | Geçti / bazen atlanır | Win11 gizli simge taşması kapanabiliyor; aynı menü ⋯ ile tam test |
| Görsel | Birincil düğme kontrastı | Koyu metin | Elle | Açık mavi üzerinde açık metin (~1.6:1) → koyu |
