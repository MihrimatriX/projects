$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$sidecar = Join-Path $root "sidecar"
New-Item -ItemType Directory -Force -Path $sidecar | Out-Null

$zipUrl = "https://exiftool.org/exiftool-13.25_64.zip"
$zipPath = Join-Path $sidecar "exiftool.zip"

Write-Host ">>> exiftool indiriliyor..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

Expand-Archive -Path $zipPath -DestinationPath $sidecar -Force

# Yeni Windows paketleri "exiftool(-k).exe" + yanında zorunlu "exiftool_files" klasörü içerir
$nested = Get-ChildItem -Path $sidecar -Recurse -Filter "exiftool*.exe" |
    Where-Object { $_.DirectoryName -ne $sidecar } | Select-Object -First 1
if (-not $nested) {
    Write-Error "exiftool.exe arşivde bulunamadı"
}

$dest = Join-Path $sidecar "exiftool.exe"
Copy-Item $nested.FullName $dest -Force
$filesDir = Join-Path $nested.DirectoryName "exiftool_files"
if (Test-Path $filesDir) {
    $destFiles = Join-Path $sidecar "exiftool_files"
    if (Test-Path $destFiles) { Remove-Item $destFiles -Recurse -Force }
    Copy-Item $filesDir $destFiles -Recurse -Force
}
Remove-Item $zipPath -Force

Get-ChildItem -Path $sidecar -Directory | Where-Object { $_.Name -like "exiftool-*" } | Remove-Item -Recurse -Force

$hash = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
Set-Content -Path (Join-Path $sidecar "exiftool.sha256") -Value "$hash  exiftool.exe" -Encoding ASCII

Write-Host "exiftool kuruldu: sidecar\exiftool.exe" -ForegroundColor Green
Write-Host "SHA256: $hash"
