$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$msix = Join-Path $PSScriptRoot "dist/ClipboardGecmisiYoneticisi.msix"

if (-not (Test-Path $msix)) {
    Write-Host ">>> MSIX bulunamadi, olusturuluyor..." -ForegroundColor Yellow
    & "$PSScriptRoot\package-msix.ps1" -Sign
}

Write-Host ">>> MSIX kuruluyor: $msix" -ForegroundColor Cyan
Add-AppxPackage -Path $msix -ForceUpdateFromAnyVersion
Write-Host "`n>>> Kurulum tamamlandi." -ForegroundColor Green
