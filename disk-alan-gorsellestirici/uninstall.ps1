$ErrorActionPreference = "Stop"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\DiskAlanGorsellestirici"
$appName = "Disk Alan Gorsellestirici"

Get-Process -Name "DiskAlanGorsellestirici" -ErrorAction SilentlyContinue | Stop-Process -Force

$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")
@(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
) | ForEach-Object { if (Test-Path $_) { Remove-Item $_ -Force } }

if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
Write-Host "Kaldirildi. Veriler korundu: $env:LOCALAPPDATA\DiskAlanGorsellestirici"
