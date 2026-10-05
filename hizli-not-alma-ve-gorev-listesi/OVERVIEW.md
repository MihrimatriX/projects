# Hızlı Not Alma ve Görev Listesi (Akıllı Yapılacaklar)

## Amaç
Todoist / Things tarzı, hızlı **not alma ve görev yönetimi** uygulaması. Günlük görevleri hızlıca yakalama ve organize etme ihtiyacını sade, hızlı ve yerel-first bir arayüzle karşılar.

## İşlevler (v1.1 — uygulamada)

### Görevler
- Görünümler: Bugün, Gelen Kutusu, Yaklaşan, Tümü, Takvim, proje, etiket
- Hızlı ekleme (Enter); `#etiket` `@bağlam` sözdizimi
- Proje/liste, renk, düzenleme/silme
- Son tarih, not, öncelik, alt görev, sürükle-bırak
- Tekrarlayan görevler (günlük/haftalık/aylık)
- Arama; tamamlananları göster/gizle

### Notlar
- Hızlı not yakalama

### Veri
- SQLite (Drift); JSON yedekleme ve geri yükleme
- Bulut hesabı yok (bilinçli tercih)

## Rakipler
- **Todoist**, **Things** — referans UX
- Fark: yerel-first, JSON taşınabilirlik, Türkçe-öncelikli, düşük karmaşıklık
- Portföy notu: **C**

## Teknoloji
- **Flutter 3.x**, Riverpod, Drift, Material 3
- Faz 3 (planlı): bulut senkron, web/self-host
