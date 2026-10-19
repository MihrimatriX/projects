$ErrorActionPreference = "Stop"

$appName = "E-posta Istemcisi"
Write-Host ">>> $appName kaldiriliyor..." -ForegroundColor Yellow

$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
$roaming = [Environment]::GetFolderPath("ApplicationData")

$paths = @(
  Join-Path $localAppData "e-posta-istemcisi-ve-takip-araci"
  Join-Path $roaming "e-posta-istemcisi-ve-takip-araci"
)

foreach ($p in $paths) {
  if (Test-Path $p) {
    Remove-Item -Recurse -Force $p
    Write-Host "Silindi: $p" -ForegroundColor Gray
  }
}

Write-Host ">>> Uygulamayi Denetim Masasi / Ayarlar uzerinden de kaldirabilirsiniz." -ForegroundColor Cyan
Write-Host ">>> Veri klasorleri temizlendi." -ForegroundColor Green
