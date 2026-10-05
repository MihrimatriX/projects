# Arayüz testi envanteri

Testler: `e2e/ui.spec.ts` (tüm ekranlar, çok kullanıcılı akış), `e2e/chat.spec.ts` (ana akışlar),
`e2e/electron.spec.ts` (masaüstü kabuğu). Çalıştırma: `.\run.ps1 -UiTest` (ui + electron), `.\run.ps1 -Check` (e2e).
Testler geçici klasörde ayrı bir SQLite (`%TEMP%\takim-sohbet-e2e`) ve 3196 portunda üretim derlemesiyle çalışır.

Sonuç sütunu: ✅ test geçiyor · 🔧 testte bulunan hata düzeltildi, test geçiyor.

| Ekran | Kontrol | Beklenen | Sonuç | Not |
|---|---|---|---|---|
| Giriş | Oturumsuz `/chat`, `/settings` | `/login`'e yönlendirir; API 401 | ✅ | |
| Giriş | Giriş / Kayıt sekmeleri | `aria-pressed` durumu, Kayıt'ta "Adınız" alanı | 🔧 | Sekmelerde durum, alanlarda erişilebilir ad yoktu |
| Giriş | Hatalı şifre | `role=alert` ile "Geçersiz e-posta veya şifre" | 🔧 | Hata ekran okuyucuya duyurulmuyordu |
| Giriş | Form gönderimi | Sayfa hidrasyonundan önce yazılan değerler de gönderilir | 🔧 | Electron'da soğuk açılışta erken yazılan e-posta/şifre kayboluyor, "Geçersiz" hatası veriyordu |
| Giriş | Kayıt ol | Yeni kullanıcı tüm genel kanallara katılır | ✅ | |
| Sohbet | Açılış kanalı | Son açılan kanal; yoksa okunmamış olan; yoksa ilk | 🔧 | Hep alfabetik ilk (boş) kanal açılıyordu, karşılama mesajları görünmüyordu |
| Sohbet | Kanal ara | Ada göre süzer | ✅ | |
| Sohbet | Yeni kanal + "Kanal oluştur" | Kanal açılır; boş durum metni; aynı ad → uyarı | 🔧 | Giriş/düğme erişilebilir adı yoktu; boş kanal tamamen boş görünüyordu |
| Sohbet | Alt+↑ / Alt+↓ | Önceki / sonraki kanal | ✅ | |
| Sohbet | Mesaj kutusu Enter / Shift+Enter | Gönderir / yeni satır; boşken Gönder pasif | ✅ | |
| Sohbet | Markdown, @mention | Kalın metin, mention vurgusu | ✅ | |
| Sohbet | Düzenle (✎), Enter / Esc | Kaydeder, "(düzenlendi)"; Esc yalnızca düzenlemeyi bırakır | 🔧 | Esc thread panelini de kapatıyordu |
| Sohbet | Sil (✕) + onay | İptal → kalır, onay → silinir (herkeste anlık) | ✅ | |
| Sohbet | Dosya ekle / Kaldır / Gönder | Ek bağlantısı, indirme `attachment` başlığıyla | 🔧 | Dosya girişinin erişilebilir adı yoktu; aynı dosya yeniden seçilemiyordu |
| Sohbet | "Daha eski mesajları yükle" | 50+ mesajda görünür, eskiler başa eklenir | 🔧 | Eski mesajlar yüklenince akış en alta kayıyordu |
| Sohbet | Üyeler paneli | Sen en üstte, çevrimiçi sayısı başlıkla tutarlı; tıklayınca DM | 🔧 | Panel kendini saymıyor, başlıkla çelişiyordu (3 vs 2) |
| Sohbet | Kenar çubuğu yerleşimi | "+" düğmesi ve alt bağlantılar kırpılmaz | 🔧 | "Kanal oluştur" düğmesi dar kenar çubuğunda kesiliyordu |
| Sohbet | Dar ekran "Menüyü aç" | Kanal listesi açılır, seçince kapanır | ✅ | |
| Thread | Thread aç / Yanıtla | Yanıt görünür, "1 yanıt" sayacı | ✅ | |
| Thread | Yanıt düzenle / sil | Yanıt silinebilir, sayaç azalır | 🔧 | Thread yanıtları silinemiyordu; silinen yanıt sayaçta kalıyordu |
| Thread | Kapat düğmesi / Esc | Panel kapanır, Üyeler paneli döner | ✅ | |
| Hızlı arama | Ctrl+K, yazma, ↑↓/Enter, fare, Esc | Sonuca gider; "Sonuç bulunamadı" boş durumu | ✅ | |
| Kısayollar | Ctrl+/ ve kenar çubuğu düğmesi | Kısayol listesi; Esc / Kapat | ✅ | Yeni |
| Çok kullanıcı | Üyeler panelinden DM | Karşı tarafta DM anlık belirir, okunmamış rozeti | 🔧 | Yeni DM ve diğer kanalların rozetleri yalnızca sayfa yenilenince geliyordu |
| Çok kullanıcı | Aktif olmayan kanala mesaj | Rozet anlık artar | 🔧 | (aynı kök neden: istemci yalnızca aktif kanal odasındaydı) |
| Çok kullanıcı | Başkasının açtığı kanal | Kenar çubuğunda anlık görünür | 🔧 | |
| Çok kullanıcı | "yazıyor" göstergesi | Diğer kullanıcıda görünür | ✅ | |
| Çok kullanıcı | Anlık düzenleme/silme | Diğer kullanıcıda yansır; başkasının mesajında düğme yok | ✅ | |
| Ayarlar | Görünen ad + Kaydet | Kaydedilir, mesajlarda yeni ad; <2 karakter tarayıcı doğrulamasında kalır | ✅ | Yeni (önceden salt okunurdu) |
| Ayarlar | Tema (Koyu / Açık) | Anında uygulanır, yeniden yüklemede korunur | ✅ | Yeni |
| Ayarlar | Webhook oluştur (çoklu) | Liste; her biri Kopyala / Test / Sil | 🔧 | Yalnızca ilk webhook gösteriliyor, ikinci oluşturulamıyor, silinemiyordu |
| Ayarlar | Webhook Test (iki farklı kanal) | "Test mesajı kanala gönderildi", mesaj kanalda | 🔧 | İkinci kanala gelen webhook "Erişim yok" ile düşüyordu; hata da başarı gibi gösteriliyordu |
| Ayarlar | Webhook Kopyala | Pano = URL | ✅ | |
| Ayarlar | Webhook Sil + onay | Silinir, URL artık çalışmaz | ✅ | |
| Ayarlar | Verilerimi dışa aktar | JSON indirme (`kvkk-export-v1`) | 🔧 | Sahte 1,2 sn "hazırlanıyor" penceresi kaldırıldı |
| Ayarlar | Hesabımı sil | E-posta yazılmadan pasif; yanlış e-posta pasif; onay → silinir | 🔧 | Onay kutusu boşken de e-posta otomatik gönderiliyor, onay atlanıyordu |
| Ayarlar | Çıkış yap | `/login`; korumalı sayfalar yönlendirir | ✅ | |
| Masaüstü | İlk açılış (Electron) | Kuruluma özel `secret.key` (64 hex), demo verili `sohbet.db`, giriş, mesaj | ✅ | `TAKIM_SOHBET_DATA` ile geçici klasör |
| Genel | Harici ağ | Google Fonts isteği yok (CSP de daraltıldı) | 🔧 | Telemetri yok iddiasına rağmen font için Google'a istek gidiyordu |
