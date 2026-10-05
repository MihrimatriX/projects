#Requires -Version 5.1
<#
.SYNOPSIS
  Canli Duvar Kagidi Motoru - bagimsiz (self-contained) exe klasoru uretir.
  Cikti: <repo>\dist\canli-duvar-kagidi-motoru\CanliDuvarKagidi.exe (+ DLL'ler, catalog\)
.DESCRIPTION
  WinUI 3 / Windows App SDK uygulamasi tek dosyaya sigmaz; bunun yerine paketsiz
  (WindowsPackageType=None) ve WindowsAppSDKSelfContained=true ile klasor ciktisi alinir.
  Hedef makinede .NET ya da Windows App Runtime gerekmez; yalnizca WebView2 Runtime (Windows 11'de hazir).
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$project = 'src\CanliDuvarKagidi.Shell\CanliDuvarKagidi.Shell.csproj'
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) ('dist\' + (Split-Path $PSScriptRoot -Leaf))

if (Get-Process -Name 'CanliDuvarKagidi' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($outDir, [StringComparison]::OrdinalIgnoreCase) }) {
    throw "Yayin klasorundeki uygulama acik; once kapatin (sistem tepsisi > Cikis): $outDir"
}
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }

Write-Host '>>> Derleniyor (Release, win-x64, self-contained, Windows App SDK gomulu)...' -ForegroundColor Cyan
& dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:Platform=x64 `
    -p:WindowsPackageType=None `
    -p:WindowsAppSDKSelfContained=true `
    -p:PublishSingleFile=false `
    -o $outDir --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish basarisiz.' }

# Ust duzeyde tek exe kalsin: createdump.exe (.NET, yalnizca cokme dokumu) ve RestartAgent.exe
# (Windows App SDK, yalnizca AppInstance.Restart icin; uygulama kullanmiyor) gerekli degil.
foreach ($extra in 'createdump.exe', 'RestartAgent.exe') {
    Remove-Item (Join-Path $outDir $extra) -ErrorAction SilentlyContinue
}

$exes = @(Get-ChildItem $outDir -Filter '*.exe' -File)
if ($exes.Count -ne 1) { throw "Cikti klasorunde tam olarak bir exe olmali (bulunan: $($exes.Name -join ', '))." }
if (-not (Test-Path (Join-Path $outDir 'catalog\index.json'))) { throw 'Gomulu katalog (catalog\index.json) ciktiya kopyalanmadi.' }
if (-not (Test-Path (Join-Path $outDir 'Assets\AppIcon.ico'))) { throw 'Pencere/tepsi simgesi (Assets\AppIcon.ico) ciktiya kopyalanmadi.' }

$sizeMb = [math]::Round(((Get-ChildItem $outDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host "`n>>> Hazir: $($exes[0].FullName)" -ForegroundColor Green
Write-Host "    Klasor boyutu: $sizeMb MB"
