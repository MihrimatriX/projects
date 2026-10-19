# Ekran Zamanı — Tarayıcı Eklentisi

Chrome / Edge (Chromium) için Manifest V3 eklentisi. Aktif sekmenin domain süresini yerel uygulamaya gönderir.

## Kurulum

1. Ekran Zamanı masaüstü uygulamasını çalıştırın (`run.ps1`).
2. Chrome veya Edge → `chrome://extensions` / `edge://extensions`
3. **Geliştirici modu** açık
4. **Paketlenmemiş öğe yükle** → bu `browser-extension` klasörünü seçin
5. Eklenti simgesinden portu ayarlayın (varsayılan `47123`, uygulama ayarlarıyla aynı olmalı)

## API

`POST http://127.0.0.1:{port}/api/web-usage`

```json
{ "domain": "github.com", "title": "Pull requests", "seconds": 30 }
```

## Davranış

- Süre site (domain) bazında toplanır; aynı sitede sayfa değişimi oturumu bölmez.
- Tarayıcı odağı kaybedince, sistem boşta (5 dk) ya da kilitliyken süre sayılmaz; odak geri gelince kaldığı sekmeden devam eder.
- Her 30 sn'de bir gönderir (`chrome.alarms`); oturum `chrome.storage.session`'da tutulduğu için MV3 service worker kapanıp açılsa da süre kaybolmaz. Tek gönderim en fazla 120 sn sayılır (uyku sonrası şişme olmaz).
- Uygulama yalnızca eklenti kökenli (`chrome-extension://`) veya Origin başlıksız istekleri kabul eder; web siteleri yerel köprüye veri yazamaz.
- Güncellemeden sonra `chrome://extensions` sayfasında eklentiyi **Yeniden yükle** (yeni izinler: `alarms`, `idle`). Chrome/Edge 120+ gerekir.
