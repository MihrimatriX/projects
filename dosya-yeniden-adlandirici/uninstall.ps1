$ErrorActionPreference = "Stop"

$appName = "Dosya Yeniden Adlandirici"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\DosyaYenidenAdlandirici"
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")

foreach ($path in @(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
)) {
    if (Test-Path $path) { Remove-Item $path -Force }
}

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "Kaldirildi: $installDir" -ForegroundColor Green
} else {
    Write-Host "Kurulum klasoru bulunamadi." -ForegroundColor Yellow
}
