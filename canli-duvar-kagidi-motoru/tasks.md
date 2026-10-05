# Canlı Duvar Kağıdı Motoru — görev listesi

**Kaynak:** Uygulama planı (Windows-only, yerel + self-host katalog)

Durum: `[ ]` yapılmadı · `[~]` devam · `[x]` bitti

## Hazırlık

- [x] Ürün modeli net: yerel masaüstü + self-host katalog
- [x] MVP sınırını yazılı sabitle (README + plan.md)
- [x] Repo ve kök klasör yapısı; MIT lisans

## Teknik

- [x] C# / WinUI 3 / WebView2 iskelet
- [x] Birincil kullanıcı akışı: katalog → indir → monitore uygula

## Kalite ve yayın

- [x] README: kurulum ve çalıştırma
- [x] `plan.md` / `tasks.md` / `progress.md` güncel
- [x] MSIX publish dokümantasyonu (`docs/msix-publish.md`)
- [x] Manuel test checklist (`docs/test-checklist.md`)
- [x] Otomatik testler (xunit, `run.ps1 -Check`) ve self-contained exe (`publish.ps1`)
- [x] Yerel dosyadan duvar kagidi ekleme (dosya secici + surukle-birak)

## Dokümantasyon

- [x] `plan.md` / `tasks.md` / `progress.md`
