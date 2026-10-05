#Requires -Version 5.1
<#
.SYNOPSIS
  Bagimsiz Windows surumu uretir: <repo>\dist\yerel-webhook-test-araci\ (tek .exe + Electron dosyalari).
  Kurulum paketi (NSIS) icin: npm run pack (cikti release\).
.EXAMPLE
  .\publish.ps1
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Fail([string]$msg) { Write-Host "HATA: $msg" -ForegroundColor Red; exit 1 }
# $tries: yeni uretilen exe kisa sure virus tarayicisi tarafindan kilitlenebilir (rcedit "Unable to commit changes").
function Run([string]$label, [scriptblock]$cmd, [int]$tries = 1) {
    for ($i = 1; $i -le $tries; $i++) {
        Write-Host ">>> $label" -ForegroundColor DarkGray
        & $cmd
        if ($LASTEXITCODE -eq 0) { return }
        if ($i -lt $tries) { Start-Sleep -Seconds 3 }
    }
    Fail "$label basarisiz (cikis kodu $LASTEXITCODE)."
}

$name = Split-Path $PSScriptRoot -Leaf
$out = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\$name"
$unpacked = Join-Path $PSScriptRoot "release\win-unpacked"
$exeName = "HookYerel.exe"

Write-Host ">>> HookYerel (Yerel Webhook Test Araci) - exe uretimi" -ForegroundColor Cyan
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail "Node.js bulunamadi." }

if (-not (Test-Path "node_modules\.package-lock.json")) { Run "npm install" { npm install } }
Run "Birim testleri" { npm test }
Run "Derleme (vite)" { npm run build }

if (Test-Path $unpacked) { Remove-Item $unpacked -Recurse -Force }
# better-sqlite3 13 N-API hazir ikiliyle gelir (Electron surumunden bagimsiz); yeniden derleme yok (npmRebuild=false).
Run "Paketleme (electron-builder --win dir)" { npx electron-builder --win dir } 2
$exe = Join-Path $unpacked $exeName
if (-not (Test-Path $exe)) { Fail "release\win-unpacked\$exeName olusmadi." }

# Gelistirici Modu kapaliyken electron-builder exe'yi duzenleyemez (signAndEditExecutable=false):
# ikon ve surum bilgisi rcedit ile yazilir.
$version = (Get-Content "package.json" -Raw | ConvertFrom-Json).version
$rcedit = Join-Path $PSScriptRoot "node_modules\rcedit\bin\rcedit-x64.exe"
if (-not (Test-Path $rcedit)) { Fail "rcedit bulunamadi (npm install calistirin)." }
Run "Exe ikonu ve surum bilgisi (rcedit)" {
    & $rcedit $exe --set-icon "assets\icon.ico" --set-file-version $version --set-product-version $version `
        --set-version-string "ProductName" "HookYerel" `
        --set-version-string "FileDescription" "HookYerel - Yerel Webhook Test Araci" `
        --set-version-string "OriginalFilename" $exeName `
        --set-version-string "CompanyName" "MihrimatriX"
} 3

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item (Join-Path $unpacked "*") $out -Recurse -Force

$exes = @(Get-ChildItem $out -Filter *.exe -File)
if ($exes.Count -ne 1) { Fail "Cikti klasorunde tam olarak bir .exe bekleniyordu, bulunan: $($exes.Count)." }

$sizeMb = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host ""
Write-Host ">>> Hazir: $($exes[0].FullName)" -ForegroundColor Green
Write-Host "    Klasor boyutu: $sizeMb MB"
