# Arayüz testi envanteri

Otomatik: `.\run.ps1 -UiTest` (pytest-qt, gerçek Windows pencereleri, `tests/ui/`, 40 test).
Testler `LOCALAPPDATA`'yı geçici klasöre yönlendirir, geçici örnek ağaç (`Ornek\`) tarar; çöpe taşıma ve
Explorer sahte işlevlerle değiştirilir (yalnızca `tmp_path` altını siler), Tekrarlanan Dosya Bulucu köprüsü
taklit edilir. Masaüstü ortak kilidi (`..\.gui.lock`) test oturumu boyunca tutulur.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Ana pencere (boş) | Yol çubuğu | "Henüz tarama yok" | **Düzeltildi** | Boş durum yalnızca ilk taramadan sonra kurulabiliyordu, açılışta boştu |
| Ana pencere (boş) | `Ctrl+E`, `Ctrl+D`, `Esc`, `Backspace`, `Alt+Home` | Bilgi mesajı / zararsız | Geçti | |
| Araç çubuğu | Tara / `F5` | Tarama, grafik, kenar paneli, tekrar adayı rozeti | Geçti | Tarama bitince odak grafiğe geçer (**eklendi**) |
| Araç çubuğu | Tara düğmesi tarama sırasında | "İptal" olur, tıklayınca durur | Geçti | |
| Araç çubuğu | Dizin Seç… / `Ctrl+O` | Seçilince tarar; iptal edilirse hiçbir şey olmaz | Geçti | |
| Araç çubuğu | Derinlik menüsü | 3 / 5 / ∞, ayara yazılır | Geçti | |
| Araç çubuğu | Tekrar adayı rozeti | Diyaloğu açar | **Düzeltildi** | "Duplicate ipucu" İngilizce jargonu kaldırıldı |
| Araç çubuğu | ☰ / `Ctrl+B` | Detay paneli aç/kapat | **Düzeltildi** | Erişilebilir ad eksikti; gizli pencerede ters çalışıyordu |
| Tarama | `Shift+F5` | Önbelleği atlar, yeni dosyaları sayar | Geçti | |
| Tarama | `Esc` / "Yeniden tara" afiş düğmesi | İptal; afişten yeniden tarar | **Düzeltildi** | Bağlantı her iptalde koparılıp yeniden kuruluyordu (RuntimeWarning) |
| Tarama | Var olmayan klasör | Hata afişi + uyarı | Geçti | |
| Sunburst | Fare tıklama | Klasöre iner | Geçti | |
| Sunburst | Sağ tık menüsü | Explorer / Burayı tara / İçine gir / Çöpe taşı | **Düzeltildi** | `QContextMenuEvent.position()` yok → menü hiç açılmıyordu (AttributeError) |
| Sunburst | Dilim etiketleri / renkler | Büyük dilimlerde klasör adı, komşu dilimler farklı renk | **Düzeltildi** | Etiket yoktu; ad özeti 7 klasörden 5'ine aynı rengi veriyordu |
| Sunburst / Treemap | Klavye: ← → ↑ ↓, Enter, Delete, Menü / `Shift+F10` | Seç, içine gir, çöpe taşı, sağ tık menüsü | **Eklendi** | Grafikler yalnızca fareyle kullanılabiliyordu; odak çerçevesi eklendi |
| Treemap | Fare tıklama, boyut metni | İçine iner; boyut okunur | **Düzeltildi** | Gri kutuda gri metin, kutunun ortasında yüzüyordu |
| Grafikler | Boş klasör | "Bu klasör boş" | **Düzeltildi** | Treemap "tarama bekleniyor" diyordu |
| Yol çubuğu | Üst düğmeler, `Backspace`, `Alt+Home`, `Esc` | Üste / köke çıkar | Geçti | Eski düğmeler silinene kadar görünür kalıyordu (**düzeltildi**) |
| Görünüm | Sunburst / Treemap düğmeleri, `Ctrl+1` / `Ctrl+2` | Görünüm değişir, ayara yazılır | **Eklendi** | Kısayollar |
| Kenar paneli | Büyük dosyalar: tek tık | Yalnızca seçer | **Düzeltildi** | Tek tık Explorer açıyordu |
| Kenar paneli | Büyük dosyalar: çift tık / Enter / sağ tık / Delete | Explorer, menü, çöpe taşıma | **Eklendi** | Listeden silmenin yolu yoktu; tam yol ipucu eklendi |
| Kenar paneli | Büyük dosyalar listesi içeriği | Yalnızca odaktaki klasörün dosyaları | **Düzeltildi** | Alt klasörde de kökün tüm listesi görünüyordu |
| Kenar paneli | "Temizle: <ad>…" | Hangi öğeyi sileceğini söyler, onay sorar | **Düzeltildi** | Düğme hedefi belirtmiyordu |
| Kenar paneli | Renk açıklaması | Etiketler tam görünür | **Düzeltildi** | Tek satırda "Videc", "Görsı" diye kırpılıyordu; düşük kontrast |
| Zaman makinesi | Noktalar | Eski taramayı yükler; değişim önceki taramaya göre | **Düzeltildi** | Her nokta güncel boyutla kıyaslanıyordu; tarih GG.AA; erişilebilir ad |
| Çöpe taşıma | Onay "Hayır" / "Evet" | Hayır'da dokunmaz; Evet'te ağaçtan, adaylardan düşer | Geçti | |
| Dosya menüsü | Dışa aktar PNG / SVG / JSON / CSV / HTML (`Ctrl+E`) | Dosya yazılır | **Düzeltildi** | SVG: `render(painter)` imzası yanlıştı, painter açık kalıp süreç çöküyordu |
| Dosya menüsü | Son klasörler | Listeler, tarar; silinmiş klasörde uyarı + listeden çıkarır; temizle | Geçti | |
| Dosya menüsü | Çık / `Ctrl+Q` | Kapanır | Geçti | |
| Tekrar adayları (`Ctrl+D`) | Liste, Seçileni göster, Enter | Explorer bir kez açılır | **Düzeltildi** | Enter hem öğeyi hem varsayılan düğmeyi tetikliyordu (iki kez); "gruları" yazım hatası; 8'den fazla dosya için "… ve N dosya daha" |
| Tekrar adayları | Tekrarlanan Dosya Bulucu'da aç | IPC başarılıysa kapanır, hatada uyarı + açık kalır | Geçti | Köprü (`core/tekrarlanan_bridge.py`) değişmedi |
| Ayarlar (`Ctrl+,`) | Alanlar, Gözat…, Kaydet / İptal | Geçersiz klasörde hata, Kaydet yazar, İptal değiştirmez | **Düzeltildi** | Klasör seçici ve doğrulama yoktu; alt sınır değişince adaylar yenilenmiyordu |
| Yardım (`F1`) | Kısayol listesi | Tüm kısayollar | **Düzeltildi** | Ctrl+Q, Esc'in iptal işlevi ve yeni kısayollar eksikti |
| Hakkında | Tamam / Esc | Kapanır | Geçti | |
| Hoş geldiniz | "Başlayalım" / "Dizin Seç…" | Kapanır; ikincisi klasör seçiciyi açar | **Düzeltildi** | "Dizin Seç…" yalnızca diyaloğu kapatıyordu |
| Zamanlanmış tarama | Vakti gelince | Ayarlı klasörü tarar; vakti gelmediyse taramaz | Geçti | |
| Tepsi | Göster · Tara · Çık | — | Elle | `main.py` içinde kurulur; exe açılışında doğrulandı |
