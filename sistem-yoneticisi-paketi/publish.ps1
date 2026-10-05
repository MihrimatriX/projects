#Requires -Version 5.1
<#
.SYNOPSIS
  Sistem Yoneticisi Paketi - bagimsiz (self-contained) tek exe uretir (.NET kurulumu gerektirmez).
  Cikti: <repo>\dist\sistem-yoneticisi-paketi\SistemYoneticisiPaketi.exe
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$project = 'SistemYoneticisi\SistemYoneticisi.csproj'
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) ('dist\' + (Split-Path $PSScriptRoot -Leaf))

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw '.NET 10 SDK gerekli: https://dotnet.microsoft.com/download/dotnet/10.0'
}
if (Get-Process -Name 'SistemYoneticisiPaketi' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$outDir\*" }) {
    throw 'dist icindeki Sistem Yoneticisi Paketi calisiyor; once tepsi simgesinden Cikis yapin.'
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

Write-Host "`n>>> Hazir: $($exes[0].FullName)" -ForegroundColor Green
Write-Host "    Boyut: $([math]::Round($exes[0].Length / 1MB, 1)) MB"
