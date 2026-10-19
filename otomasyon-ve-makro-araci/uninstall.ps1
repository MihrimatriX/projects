$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Otomasyon ve Makro Araci"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\OtomasyonMakro"

Write-Host ">>> Kaldiriliyor: $installDir" -ForegroundColor Cyan

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
}

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")

$shortcutPaths = @(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
)

foreach ($path in $shortcutPaths) {
    if (Test-Path $path) {
        Remove-Item $path -Force
    }
}

Write-Host ">>> Kaldirma tamamlandi." -ForegroundColor Green
Write-Host "    Makrolar korundu: $(Join-Path $env:LOCALAPPDATA 'OtomasyonMakro') (tamamen silmek icin bu klasoru elle silin)."
