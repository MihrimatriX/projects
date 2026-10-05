# Arayüz testi envanteri

Otomatik testler: `tests/CanliDuvarKagidi.UiTests` (FlaUI UIA3 + xunit v3), `.\run.ps1 -UiTest` ile çalışır.
Uygulama geçici veri klasörü (`CANLI_DUVAR_DATA`) ve test kipiyle (`CANLI_DUVAR_UITEST=1`) açılır:
"uygula" masaüstüne pencere gömmez (kullanıcının duvar kağıdı değişmez), "Windows başlangıcında çalıştır"
kayıt defterine yazılmaz, pencereyi kapatmak süreci kapatır. Etkileşimler UIA desenleriyle
(Invoke / Value / Toggle / SelectionItem / ExpandCollapse) yapılır; yalnızca klavye kısayolu testi gerçek
klavye kullanır ve ortak `.gui.lock` kilidini alır. Yayınlanmış exe ile de çalışır (`CDK_UITEST_EXE`).

Sonuç: ✅ otomatik test geçti · 🔧 bu turda düzeltildi · 👁 elle doğrulandı · — otomatikleştirilemez

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Genel | Gezinme: Kütüphanem / Mağaza / Monitörler / Ayarlar | Başlık ve panel değişir | ✅ | `Nav_*` AutomationId |
| Genel | Ctrl+1..4 | İlgili bölüme geçer | ✅ 🔧 | Yeni kısayollar |
| Genel | Ctrl+P | Tüm duvar kağıtlarını duraklat/devam | ✅ 🔧 | Yeni |
| Genel | Pencere simgesi | Uygulama simgesi | 👁 🔧 | Şablon yer tutucu simge vardı; yeni simge, artık yayına da kopyalanıyor (ekran görüntüsünde görünür) |
| Kütüphanem | Kart listesi | Kurulu örnekler, sayaç = kart sayısı | ✅ 🔧 | Kartın erişilebilir adı sınıf adıydı (`...WallpaperListItem`), artık "Başlık, Tür" |
| Kütüphanem | Arama kutusu (Ctrl+F) | Ad/açıklama/türe göre süzer, Türkçe karaktersiz yazım da bulur | ✅ 🔧 | Yeni |
| Kütüphanem | Arama boş sonuç | "Eşleşen duvar kağıdı yok", "Mağazaya git" gizli | ✅ 🔧 | Yeni boş durum |
| Kütüphanem | Monitöre uygula (seçimsiz) | Uyarı InfoBar | ✅ | |
| Kütüphanem | Monitöre uygula | Birincil monitöre uygulanır, ayar kaydedilir | ✅ | |
| Kütüphanem | Kart odakta: Enter (uygula), Delete (kaldır onayı); çift tık | Düğmelerle aynı işleyici | ✅ 🔧 | Yeni; Enter/Delete gerçek klavyeyle test edilir (GridViewItem Enter'i yuttuğu için PreviewKeyDown). Çift tık otomatik testte yok |
| Kütüphanem | Dosyadan ekle (Ctrl+O) | Dosya seçici açılır, seçilen görsel eklenir | ✅ | Gerçek Windows dosya iletişim kutusu UIA ile dolduruldu |
| Kütüphanem | Sürükle-bırak | Dosyalar kütüphaneye eklenir | — | UIA ile sürükle-bırak yok; aynı `ImportFile` birim testli |
| Kütüphanem | Kaldır | Onay iletişim kutusu; Vazgeç silmez, Kaldır siler | ✅ 🔧 | Önce onaysız siliyordu (geri alınamaz) |
| Kütüphanem | Yenile (F5) | Liste ve monitörler yenilenir | ✅ | |
| Mağaza | İlk ziyaret | Katalog otomatik yüklenir | ✅ 🔧 | Önce boş durum gösterip ek tık istiyordu |
| Mağaza | Kartlar | Kurulu olanlar "· Kurulu" etiketli, açıklama 2 satır | ✅ 🔧 | Açıklama tek satırda kırpılıyordu |
| Mağaza | İndir ve kur (seçimsiz / seçili) | Uyarı / "kuruldu" | ✅ | |
| Mağaza | Katalogu yükle (F5) | Yeniden yükler | ✅ | |
| Monitörler | Monitör kartları | Ad, çözünürlük, atanan duvar kağıdı; ekran okuyucuya tek öğe | ✅ 🔧 | ItemsRepeater → GridView (UIA'da kartlar görünmüyordu) |
| Monitörler | Duraklat anahtarı | Kartlarda "(duraklatıldı)"; tepsi menüsüyle eş | ✅ 🔧 | Yeni |
| Monitörler | Monitör / duvar kağıdı seçimi + Uygula | Atanır | ✅ | |
| Monitörler | Kaldır | Kaldırır; ikinci kez "atanmış duvar kağıdı yok" | ✅ 🔧 | Uygula/Kaldır sonrası seçim sıfırlanıyor, ikinci işlem "Monitör seçin." diyordu |
| Ayarlar | Katalog URL | Geçersiz adres (ör. ftp://) reddedilir | ✅ 🔧 | Önce her metin kaydediliyordu |
| Ayarlar | Tam ekranda duraklat / Windows ile başlat | Kaydet ile `settings.json`'a yazılır | ✅ | Test kipinde Run anahtarına dokunulmadığı doğrulanır |
| Ayarlar | Ayarları kaydet (Ctrl+S) | "Ayarlar kaydedildi." | ✅ 🔧 | Düğme "Depolama" kartındaydı, ayrı satıra taşındı |
| Ayarlar | Önbelleği temizle | "Önbellek temizlendi." | ✅ | |
| Tepsi | Göster / Duraklat / Çıkış | Menü Türkçe, Duraklat işaretli gösterilir | — 🔧 | "Goster/Cikis" ASCII'ydi; çıkışta simge kalıyordu (dispose yoktu) |
| Genel | Koyu tema / yüksek DPI | Koyu tema sabit, PerMonitorV2 | 👁 | Ekran görüntüleri 1280×800 |
