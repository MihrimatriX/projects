$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Sistem Yöneticisi Paketi"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\SistemYoneticisiPaketi"
$dataDir = Join-Path $env:LOCALAPPDATA "SistemYoneticisiPaketi"

Write-Host ">>> Kaldiriliyor: $appName" -ForegroundColor Cyan

Get-Process -Name "SistemYoneticisiPaketi" -ErrorAction SilentlyContinue | Stop-Process -Force

# "Oturum acilisinda baslat" kaydini da temizle (silinen exe'yi gostermesin)
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SistemYoneticisiPaketi" -ErrorAction SilentlyContinue

$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")
$shortcuts = @(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
)

foreach ($path in $shortcuts) {
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "    Kisayol silindi: $path"
    }
}

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "    Kurulum klasoru silindi: $installDir"
}

$removeData = Read-Host "Kullanici verilerini de sil (ayarlar, gecmis DB, kaldirilan baslangic ogesi yedekleri)? [y/N]"
if ($removeData -eq "y" -or $removeData -eq "Y") {
    if (Test-Path $dataDir) {
        Remove-Item $dataDir -Recurse -Force
        Write-Host "    Veri klasoru silindi: $dataDir" -ForegroundColor Yellow
    }
}

Write-Host "`n>>> Kaldirma tamamlandi." -ForegroundColor Green
