# MVP test checklist

- [ ] Tek monitör: video, web, statik — uygula / kaldır
- [ ] İki monitör: farklı wallpaper'lar
- [ ] Katalogdan indir → uygula (localhost:8080)
- [ ] Uygulama yeniden başlat → son wallpaper geri gelir
- [ ] Explorer restart → wallpaper yeniden bağlanır
- [ ] Fullscreen oyun / video → pause; çıkınca resume
- [ ] Masaüstü simgeleri ve taskbar normal çalışır
- [ ] Pencere kapat → tepsi simgesi kalır; çift tık → pencere açılır
- [ ] Ayarlar: katalog URL kaydı, önbellek temizleme

## Test komutları

```powershell
# Katalog sunucusu
.\catalog\serve.ps1

# Uygulama
dotnet run --project src\CanliDuvarKagidi.Shell -p:Platform=x64
```

## Explorer restart testi

```powershell
taskkill /f /im explorer.exe; Start-Process explorer.exe
```

Duvar kağıdının 3–10 saniye içinde yeniden görünmesi beklenir.
