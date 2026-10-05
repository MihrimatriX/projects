# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (FlaUI/UIA3, sahte repo kökü, gerçek proje başlatılmaz). Klavye testi
gerçek tuş girdisi gönderdiği için ortak `.gui.lock` kilidi içinde ve pencere ön plandaysa çalışır.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Galeri | Açılış | 5 sahte proje kartı yüklenir, `dist`, `.hidden`, `proje-launcher`, boş klasör listelenmez | Geçti | Eski katalog `dist` klasörünü proje sayıyordu (düzeltildi) |
| Galeri | Arama kutusu (`SearchBox`) | `ISTANBUL` → "İstanbul Öğrenme Aracı"; sonuç metni `1 / 5 proje` | Geçti | Türkçe katlama: İ/I/ı/i, ö/ğ/ü/ş/ç |
| Galeri | Boş durum | Eşleşme yokken "Eşleşen proje yok" görünür | Geçti | Panel UIA ağacında yoktu; kimlik metne taşındı |
| Kenar çubuğu | Teknoloji (Flutter) | Yalnız Flutter projesi | Geçti | |
| Kenar çubuğu | Kategori (Verimlilik) | Büyük/küçük harf farklı iki manifest tek kategori | Geçti | |
| Kenar çubuğu | Başlık öğeleri | Seçilemez | Geçti (birim) | |
| Galeri | Exe filtresi (Hepsi / Exe var / Exe yok) | 5 / 1 / 4 kart | Geçti | |
| Galeri | Kart seçimi | `SelectionItem` ile seçilir, halka görünür | Geçti | |
| Kart | Ayrıntılar düğmesi | Detay sayfası açılır, galeri gizlenir | Geçti | Fare dışı erişim için eklendi |
| Kart | Aç düğmesi | Exe varsa exe, yoksa kaynaktan | Geçti (birim) | |
| Kart | Favori yıldızı | Favorilere ekler/çıkarır | Geçti (birim) | |
| Detay | Başlık, etiketler, ekran görüntüsü şeridi | Manifest adı, `regex` etiketi, 2 görüntü | Geçti | |
| Detay | Kaynaktan çalıştır | `launcher.ps1 -Exec alpha-dotnet` yeni konsolda | Geçti | Sahte launcher `launched.txt` yazar |
| Detay | Exe üret / Testleri çalıştır | `-Publish <klasör>` / `run.ps1 -Check`, konsol açık kalır | Geçti (birim) | `-NoExit` |
| Detay | Favori düğmesi | `state.json` atomik yazılır | Geçti | |
| Detay | Galeri (geri) | Galeriye döner, odak seçili karta | Geçti | |
| Kenar çubuğu | Son kullanılanlar / Favoriler | Başlatılan ve favorilenen proje listelenir | Geçti | |
| Durum çubuğu | Araç zinciri | 4 araç (.NET, Flutter, Python, Node) | Geçti | `launcher.ps1 -Doctor` ile aynı denetim |
| Klavye | Ctrl+F, yazma | Arama kutusu odaklanır, süzer | Geçti | |
| Klavye | Esc | Önce detay, sonra arama, sonra filtreler temizlenir | Geçti | |
| Klavye | ↓ (aramadan) / oklar / Enter | İlk kart seçilir; Enter detay açar | Geçti | Eskiden Enter doğrudan başlatıyordu → Ctrl+Enter |
| Klavye | F5 | Katalog yenilenir | Geçti | |
| Görsel | Açık / koyu tema, 720x520 | Fluent tema, kırpılma yok | Elle (ekran görüntüsü) | `DEVPROJECTS_THEME=Light` |
