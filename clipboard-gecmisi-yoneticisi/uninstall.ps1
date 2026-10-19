$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Clipboard Ge$([char]0x00E7)mi$([char]0x015F)i Y$([char]0x00F6)neticisi"  # ASCII betik (PS 5.1 BOM-suz UTF-8 okumaz)
$installDir = Join-Path $env:LOCALAPPDATA "Programs\ClipboardGecmisiYoneticisi"
$exeName = "ClipboardGecmisiYoneticisi.exe"

Write-Host ">>> Kaldiriliyor: $appName" -ForegroundColor Cyan

# Running process
Get-Process -Name "ClipboardGecmisiYoneticisi" -ErrorAction SilentlyContinue | Stop-Process -Force

# Startup registry
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Remove-ItemProperty -Path $runKey -Name "ClipboardGecmisiYoneticisi" -ErrorAction SilentlyContinue

# Shortcuts
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")
@(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
) | ForEach-Object {
    if (Test-Path $_) { Remove-Item $_ -Force }
}

# Install folder
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "    Program klasoru silindi." -ForegroundColor Green
}

Write-Host "`n>>> Kaldirma tamamlandi." -ForegroundColor Green
Write-Host "    Not: Kullanici verileri korundu:" -ForegroundColor Yellow
Write-Host "    $env:LOCALAPPDATA\ClipboardGecmisiYoneticisi"
