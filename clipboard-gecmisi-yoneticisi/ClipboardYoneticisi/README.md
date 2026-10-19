# ClipboardYoneticisi (WPF)

Pano Geçmişi Yöneticisi'nin Windows uygulama projesi (.NET 10, WPF, MVVM). Genel bilgi için kök `README.md`.

## Çalıştırma

```powershell
dotnet run --project ClipboardYoneticisi
```

veya kök dizinden `.\run.ps1`.

## Klasörler

- `Services/` — pano dinleme, SQLite (FTS5), şifreleme, ayarlar, OCR, güncelleme kontrolü
- `ViewModels/` — `MainViewModel` (CommunityToolkit.Mvvm)
- `Models/`, `Helpers/` — öğe modeli, sınıflandırma, dönüşümler, Win32 P/Invoke
- `*.xaml` — ana panel ve ayar/kilit/hakkında pencereleri

## Paketler

CommunityToolkit.Mvvm, Microsoft.Data.Sqlite, Hardcodet.NotifyIcon.Wpf, NHotkey.Wpf

Ayarlar: `%LocalAppData%\ClipboardGecmisiYoneticisi\settings.json`
