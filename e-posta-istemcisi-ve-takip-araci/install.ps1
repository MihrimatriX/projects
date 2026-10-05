$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$installer = Get-ChildItem -Path "release" -Filter "*Setup*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $installer) {
  Write-Host "Once publish.ps1 calistirin." -ForegroundColor Yellow
  exit 1
}

Write-Host ">>> Kurulum: $($installer.Name)" -ForegroundColor Cyan
Start-Process -FilePath $installer.FullName -Wait
Write-Host ">>> Tamamlandi" -ForegroundColor Green
