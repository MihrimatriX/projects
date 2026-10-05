# Tekrarlanan Dosya Bulucu — Agent Rehberi

## Misyon

dupeGuru / fdupes tarzı **hash tabanlı mükerrer dosya bulucu**: hızlı tarama, grup görünümü, güvenli silme (çöp kutusu). Portföy **B**.

## Durum

| Alan | Değer |
|------|--------|
| **Sürüm** | **v1.5.0** — üretim-nihai, bakım modu |
| **Stack** | Python 3.11+ · **PySide6** · `send2trash` |
| **Faz 2** | v1.0–v1.5 tamamlandı (`tasks.md`) |
| **v2 plan** | Tauri 2 + Rust (`plan.md` — gelecek) |

## Stack (uygulanan)

| Katman | Tercih |
|--------|--------|
| UI | **PySide6** — `ui/main_window.py` |
| Motor | `utils/duplicates.py` — SHA-256 iki aşamalı |
| Opsiyonel | `image_similarity.py` (pHash) |
| Veri | SQLite önbellek, JSON geçmiş, IPC handoff |
| Test | **pytest** — `tests/` |
| Dağıtım | `publish.ps1` / `.sh`, CI Win+Linux |

> **Gelecek (`plan.md` only):** Tauri 2 + Rust / BLAKE3 — uygulanmadı.

## Önce Oku

1. `README.md`
2. `THREAT_MODEL.md`
3. `CHANGELOG.md`

## Dizin Yapısı

```
tekrarlanan-dosya-bulucu/
├── main.py                 # tray, IPC sunucusu, CLI
├── ui/main_window.py
├── utils/
│   ├── duplicates.py       # byte-dup motor
│   ├── ipc.py              # QLocalServer handoff (çalışan örnek)
│   ├── handoff.py          # dosya + CLI payload
│   ├── session.py          # oturum kaydet/yükle
│   ├── scan_cache.py / scan_history.py / log_service.py
│   └── image_similarity.py
├── packaging/build-macos.sh
└── AGENTS.md
```

## Portföy Köprüsü

`disk-alan-gorsellestirici/core/tekrarlanan_bridge.py` → `handoff.json` veya çalışan örnek → **IPC** (`utils/ipc.py`).

İkinci süreç: `QLocalSocket` ile payload gönderir, çıkar. Çalışan pencere `apply_external_handoff` ile kök ekler ve isteğe bağlı tarar.

## Özellik Matrisi (tamamlanan)

| Sürüm | Özet |
|-------|------|
| v1.0 | MVP hash, silme, JSON export |
| v1.1 | Önbellek, paralel hash, menü, publish |
| v1.2 | Ağaç, zamanlama, pHash, disk köprüsü, HTML |
| v1.3 | Sanal liste, sürükle-bırak, sıralama, geçmiş, grup detay |
| v1.4 | **IPC handoff**, oturum kaydı, `app.log`, `--version`, macOS build script |
| v1.5 | **Üretim-nihai**: tek örnek, IPC-önce launch/köprü, publish/install/uninstall, tam test |

## Faz 2 / v2 (`tasks.md`)

| Aşama | Durum |
|-------|--------|
| v1.0–v1.5 (önbellek, pHash, IPC, publish, test) | **tamamlandı** |
| v2 Tauri 2 + Rust motor | planlı |
| İmzalı macOS noterizasyon / Store | planlı |

## CLI

```powershell
python main.py --version
python main.py --roots "C:\Downloads;C:\Photos" --scan
python main.py --handoff
python main.py --forward-handoff --handoff   # IPC only (exit 0/1)
```

```bash
./publish.sh && ./install.sh
```

## Veri dosyaları

```
%LocalAppData%\TekrarlananDosyaBulucu\
├── settings.json
├── scan_cache.db
├── scan_history.json
├── handoff.json
└── app.log
```

## Agent Yap / Yapma

| Yap | Yapma |
|-----|-------|
| IPC ile ikinci örnek handoff | Sessiz ikinci exe açmak |
| `GroupsListView` 120+ grup | 10k ağaç öğesi |
| `AGENTS.md` güncel tut | Tauri-only stack varsaymak |

## Test

```powershell
.\run.ps1 -Check    # pytest, tests/ui hariç (offscreen)
.\run.ps1 -UiTest   # pytest-qt arayüz testleri, gerçek pencereler, ..\.gui.lock kilidiyle
```

Testler `TEKRARLANAN_DATA_DIR` (veri klasörü) ve `TEKRARLANAN_IPC_NAME` (IPC kanalı) ile izole edilir (`tests/conftest.py`).
CI: Windows + Ubuntu (offscreen Qt).

## Yayın

```powershell
.\publish.ps1
.\install.ps1
```

macOS geliştirme: `packaging/build-macos.sh`
