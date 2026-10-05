#Requires -Version 5.1
<#
.SYNOPSIS
  Hizli Ekran Kaydi - bagimsiz (self-contained) tek exe uretir (.NET kurulumu gerektirmez).
  Cikti: <repo>\dist\hizli-ekran-kaydi-ve-gif-olusturucu\EkranKaydi.exe (+ ffmpeg\ alt klasoru)
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$project = 'EkranKaydi\EkranKaydi.csproj'
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) ('dist\' + (Split-Path $PSScriptRoot -Leaf))

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw '.NET 10 SDK gerekli: https://dotnet.microsoft.com/download/dotnet/10.0'
}
if (Get-Process -Name 'EkranKaydi' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$outDir\*" }) {
    throw 'dist icindeki Ekran Kaydi calisiyor; once uygulamayi kapatin.'
}
if (-not (Test-Path 'EkranKaydi\ffmpeg.exe')) {
    Write-Host 'UYARI: EkranKaydi\ffmpeg.exe yok - exe ffmpeg olmadan uretilecek (kullanici: winget install Gyan.FFmpeg).' -ForegroundColor Yellow
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

$total = (Get-ChildItem $outDir -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "`n>>> Hazir: $($exes[0].FullName)" -ForegroundColor Green
Write-Host "    Exe: $([math]::Round($exes[0].Length / 1MB, 1)) MB, klasor toplami (ffmpeg dahil): $([math]::Round($total / 1MB, 1)) MB"
