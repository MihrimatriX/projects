$ErrorActionPreference = "Stop"

$appName = "Tekrarlanan Dosya Bulucu"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\TekrarlananDosyaBulucu"
$desktop = [Environment]::GetFolderPath("Desktop")
$lnk = Join-Path $desktop "$appName.lnk"

if (Test-Path $lnk) { Remove-Item $lnk -Force }
if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }

Write-Host ">>> Kaldirildi: $installDir" -ForegroundColor Green
