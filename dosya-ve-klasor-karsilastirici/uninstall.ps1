$ErrorActionPreference = "Stop"

$appName = "Dosya ve Klasor Karsilastirici"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\DosyaKarsilastirici"
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
$lnk = "$appName.lnk"

foreach ($path in @(
    (Join-Path $desktop $lnk),
    (Join-Path $startMenu $lnk)
)) {
    if (Test-Path $path) { Remove-Item $path -Force }
}

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "Kaldirildi: $installDir" -ForegroundColor Green
} else {
    Write-Host "Kurulum klasoru bulunamadi." -ForegroundColor Yellow
}
