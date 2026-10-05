#Requires -Version 5.1
<#
.SYNOPSIS
  Pano Gecmisi Yoneticisi - bagimsiz (self-contained) tek exe uretir.
  Cikti: <repo>\dist\clipboard-gecmisi-yoneticisi\ClipboardGecmisiYoneticisi.exe
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$project = 'ClipboardYoneticisi\ClipboardYoneticisi.csproj'
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) ('dist\' + (Split-Path $PSScriptRoot -Leaf))

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }

Write-Host '>>> Derleniyor (Release, win-x64, self-contained, tek dosya)...' -ForegroundColor Cyan
& dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -o $outDir --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish basarisiz.' }

$exes = @(Get-ChildItem $outDir -Filter '*.exe' -File)
if ($exes.Count -ne 1) { throw "Cikti klasorunde tam olarak bir exe olmali (bulunan: $($exes.Count))." }

$exe = $exes[0].FullName
Write-Host "`n>>> Hazir: $exe" -ForegroundColor Green
Write-Host "    Boyut: $([math]::Round($exes[0].Length / 1MB, 1)) MB"
