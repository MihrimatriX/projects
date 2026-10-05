#Requires -Version 5.1
<#
.SYNOPSIS
  Komut Paleti - bagimsiz (self-contained) tek exe uretir (.NET kurulumu gerektirmez).
  Cikti: <repo>\dist\evrensel-uygulama-ve-dosya-baslatici\KomutPaleti.exe
.PARAMETER Zip
  Ayrica <repo>\dist\evrensel-uygulama-ve-dosya-baslatici-win-x64.zip olusturur.
#>
param([switch]$Zip)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$project = 'UygulamaBaslatici\UygulamaBaslatici.csproj'
$folder = Split-Path $PSScriptRoot -Leaf
$distRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'
$outDir = Join-Path $distRoot $folder

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw '.NET 10 SDK gerekli: https://dotnet.microsoft.com/download/dotnet/10.0'
}
if (Get-Process -Name 'KomutPaleti' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$outDir\*" }) {
    throw "dist icindeki Komut Paleti calisiyor; once kapatin (Alt+Space ile acip Alt+F4)."
}

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }

Write-Host '>>> Derleniyor (Release, win-x64, self-contained, tek dosya)...' -ForegroundColor Cyan
& dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=none `
    -o $outDir --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish basarisiz.' }

$exes = @(Get-ChildItem $outDir -Filter '*.exe' -File)
if ($exes.Count -ne 1) { throw "Cikti klasorunde tam olarak bir exe olmali (bulunan: $($exes.Count))." }
$exe = $exes[0].FullName

Write-Host "`n>>> Hazir: $exe" -ForegroundColor Green
Write-Host "    Boyut: $([math]::Round($exes[0].Length / 1MB, 1)) MB"

if ($Zip) {
    $zipPath = Join-Path $distRoot "$folder-win-x64.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$outDir\*" -DestinationPath $zipPath -Force
    Write-Host ">>> Zip: $zipPath" -ForegroundColor Green
}
