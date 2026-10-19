#Requires -Version 5.1
<#
.SYNOPSIS
  Dosya ve Klasor Karsilastirici'yi gelistirme modunda baslatir (Vite :5171 + Electron).
.PARAMETER Check
  Uygulamayi baslatmaz: tip kontrolu, vitest birim testleri ve derleme.
.PARAMETER UiTest
  Derleyip Playwright _electron arayuz testlerini calistirir (gercek pencere acar, gecici profil kullanir).
.EXAMPLE
  .\run.ps1
  .\run.ps1 -Check
  .\run.ps1 -UiTest
#>
param([switch]$Check, [switch]$UiTest)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Port = 5171

function Fail([string]$msg) { Write-Host "HATA: $msg" -ForegroundColor Red; exit 1 }

Write-Host ">>> Dosya ve Klasor Karsilastirici" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Fail "Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurup tekrar deneyin."
}

# npm install yalnizca node_modules yoksa veya package-lock.json daha yeniyse
$stamp = "node_modules\.package-lock.json"
if (-not (Test-Path $stamp) -or ((Get-Item "package-lock.json").LastWriteTime -gt (Get-Item $stamp).LastWriteTime)) {
    Write-Host "Bagimliliklar kuruluyor (npm install)..." -ForegroundColor DarkGray
    npm install
    if ($LASTEXITCODE -ne 0) { Fail "npm install basarisiz oldu (cikis kodu $LASTEXITCODE)." }
    (Get-Item $stamp).LastWriteTime = Get-Date
}

if (-not (Test-Path "node_modules\electron\dist\electron.exe")) {
    Write-Host "Electron ikili dosyasi indiriliyor..." -ForegroundColor DarkGray
    node node_modules/electron/install.js
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "node_modules\electron\dist\electron.exe")) { Fail "Electron indirilemedi. Internet baglantinizi kontrol edin." }
}

if ($Check -or $UiTest) {
    $steps = if ($UiTest) { @('build', 'test:e2e') } else { @('typecheck', 'test', 'build') }
    foreach ($step in $steps) {
        Write-Host "npm run $step" -ForegroundColor DarkGray
        npm run $step
        if ($LASTEXITCODE -ne 0) { Fail "npm run $step basarisiz (cikis kodu $LASTEXITCODE)." }
    }
    Write-Host "Tum kontroller gecti." -ForegroundColor Green
    exit 0
}

$busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($busy) {
    $proc = Get-Process -Id $busy.OwningProcess -ErrorAction SilentlyContinue
    Fail "Port $Port baska bir islem tarafindan kullaniliyor ($($proc.ProcessName), PID $($busy.OwningProcess)). Uygulama zaten acik olabilir; o islemi kapatip tekrar deneyin."
}

Write-Host "Uygulama baslatiliyor (http://localhost:$Port)..." -ForegroundColor Green
npm run dev
exit $LASTEXITCODE
