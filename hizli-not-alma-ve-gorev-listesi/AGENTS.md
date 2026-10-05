# Hızlı Not Alma ve Görev Listesi — Agent Rehberi

**Durum:** v1.1.0 · **Stack (uygulanan):** Flutter 3 + Riverpod + Drift SQLite

> `plan.md` / `OVERVIEW.md` Next.js + Supabase önerisi — **uygulanmadı**; mevcut Flutter stack korunur.

## Misyon

Todoist / Things tarzı **hızlı not alma ve görev yönetimi**. Portföy notu **C**. Fark: yerel-first, Türkçe UX, hızlı inbox, isteğe bağlı JSON yedek — bulut zorunlu değil.

## Önce Oku

1. `OVERVIEW.md` — kapsam ve fazlar
2. `design/DESIGN.md` — renk token'ları, bileşenler
3. `design/mockup.html` — sidebar + liste mockup'ı
4. `tasks.md` — tamamlanan / bekleyen işler

## Stack (2025–2026) — uygulanan

| Katman | Tercih |
|--------|--------|
| Framework | **Flutter 3.x** + Dart ≥3.2 |
| State | **flutter_riverpod** 2.x |
| Veri | **drift** 2.x + SQLite (`not_gorev.sqlite`) |
| UI | Material 3, `google_fonts` (Inter), `design/DESIGN.md` |
| Navigasyon | **AppShell** (sidebar / alt nav) |
| Tarih | `intl` + `initializeDateFormatting('tr_TR')` |

**Bu klasörde çalışan uygulama Flutter'dır.** Next.js / Prisma yolu yalnızca gelecekteki web/self-host dalı için referans (`plan.md`); şu an implemente edilmez.

## Sürüm 1.1 — Dahil Özellikler

### Görevler
- Görünümler: **Bugün**, **Gelen Kutusu**, **Yaklaşan**, **Tümü**, **Takvim**, proje, etiket
- Hızlı ekleme: `#etiket` `@bağlam` sözdizimi (`core/task_input_parser.dart`)
- Proje: oluştur, uzun bas → düzenle/sil, renk
- Görev: başlık, tamamla, son tarih, not, öncelik (düşük/yüksek), alt görev
- **Tekrarlayan**: günlük / haftalık / ay (`RepeatRule`); tamamlanınca yeni kopya (`core/recurrence.dart`)
- Sürükle-bırak sıralama
- Arama kutusu (başlık, not, etiket adı)
- Tamamlananları göster/gizle (ayar)

### Notlar
- Hızlı not listesi (ayrı sekme)

### Ayarlar
- Aydınlık / koyu tema
- JSON dışa / içe aktar (sürüm 2 şeması)
- Tüm veriyi sil

## Veritabanı (Drift şema v2)

| Tablo | Açıklama |
|-------|----------|
| `projects` | id, name, colorIndex, sortOrder |
| `tasks` | id, title, done, dueDate, projectId, sortOrder, note, **priority**, **repeatRule** |
| `subtasks` | id, taskId, title, done, sortOrder |
| `tags` | id, name (# veya @ önekli), colorIndex |
| `task_tags` | taskId + tagId |
| `quick_notes` | id, body, updatedAt |

Migration: `schemaVersion` 2 — v1'den `priority`, `repeatRule`, `tags`, `task_tags` eklenir.

Eski SharedPreferences (`tasks_v1`, `quick_notes_v1`) → `migrateLegacyPrefs()` ile bir kez taşınır.

## Dizin Yapısı

```
hizli-not-alma-ve-gorev-listesi/
├── AGENTS.md
├── lib/
│   ├── main.dart              # locale init + legacy migration
│   ├── app.dart
│   ├── core/
│   │   ├── database/          # app_database.dart (+ .g.dart)
│   │   ├── task_filters.dart
│   │   ├── task_input_parser.dart
│   │   ├── recurrence.dart
│   │   ├── export_service.dart / import_service.dart
│   │   └── theme/
│   └── features/
│       ├── shell/             # AppShell (sidebar / bottom nav)
│       ├── tasks/
│       ├── projects/
│       ├── tags/
│       ├── notes/
│       └── settings/
├── design/
├── test/
└── .github/workflows/ci.yml
```

## Provider Özeti

| Provider | Rol |
|----------|-----|
| `databaseProvider` | Tek `AppDatabase` örneği |
| `tasksProvider` | Tüm görevler |
| `filteredTasksProvider` | view + arama + showCompleted |
| `taskViewProvider` | Aktif sidebar görünümü |
| `projectsProvider` / `tagsProvider` | Liste CRUD |
| `themeModeProvider` / `showCompletedProvider` | UI tercihleri |

## Komutlar

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

## Faz 2+ — Henüz Yok (yapma / ayrı proje)

| Özellik | Not |
|---------|-----|
| Bulut senkron / auth | Supabase veya self-host ayrı initiative |
| Tam RRULE | Şu an daily/weekly/monthly yeterli |
| Paylaşımlı projeler | Çok kullanıcılı backend gerekir |
| Web PWA + global shortcut | Flutter web veya Next.js dalı |
| Markdown render | Not alanı düz metin; MD önizleme isteğe bağlı |
| `takvim-ve-zamanlayici` | Tam takvim uygulaması — kapsam dışı |

## Agent Yap / Yapma

| Yap | Yapma |
|-----|-------|
| Drift migration ile şema değiştir | SharedPreferences'a yeni veri yaz |
| `parseTaskInput` ile hızlı eklemeyi genişlet | Elle etiket UI'sı zorunlu kıl |
| `saveTask` kullan (`update` Riverpod ile çakışır) | `TasksNotifier.update` adlandır |
| Export/import `version: 2` koru | Kırık JSON import etme |
| Türkçe kullanıcı metinleri | İngilizce-only UI |
| Küçük odaklı PR'lar | Todoist'in tüm özellik seti |

## Test Stratejisi

| Dosya | Kapsam |
|-------|--------|
| `task_filters_test.dart` | inbox, bugün filtreleri |
| `task_input_parser_test.dart` | #/@ ayrıştırma |
| `recurrence_test.dart` | nextDueDate |
| `widget_test.dart` | AppShell + Bugün |

## Performans Hedefleri

| Metrik | Hedef |
|--------|-------|
| Görev ekleme | < 100 ms hissedilen gecikme |
| 500 görev listesi | akıcı scroll |
| DB açılış | < 300 ms |

## Güvenlik

- Veri yalnızca cihazda; export kullanıcı kontrolünde
- İçe aktarma mevcut verinin üzerine yazar — onay metni göster
- `clearAll` geri alınamaz — dialog zorunlu

## Rakip Referans

**Todoist** — feature-rich. **Things** — premium UX, Apple. Bizim fark: yerel SQLite, JSON taşınabilirlik, Türkçe-first, sade inbox — ekip/bulut Faz 2+.
