#Requires -Version 5.1
<#
.SYNOPSIS
  HookYerel (yerel webhook test araci) - gelistirme modu (Vite :5174 + Electron).
  -Prod  : derleyip calistirir (npm run start)
  -Build : bagimsiz exe uretir (publish.ps1 -> <repo>\dist\yerel-webhook-test-araci\)
  -Check : tip kontrolu, vitest birim testleri ve derleme (uygulamayi acmaz)
  -UiTest: derleyip Playwright _electron arayuz + e2e testlerini calistirir (pencere acar, gecici veri klasoru)
.EXAMPLE
  .\run.ps1
  .\run.ps1 -Check
  .\run.ps1 -UiTest
#>
param([switch]$Prod, [switch]$Build, [switch]$Check, [switch]$UiTest)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Port = 5174
$Electron = Join-Path $PSScriptRoot "node_modules\electron\dist\electron.exe"

function Fail([string]$msg) { Write-Host "HATA: $msg" -ForegroundColor Red; exit 1 }

Write-Host ">>> HookYerel" -ForegroundColor Cyan

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

if (-not (Test-Path $Electron)) {
    Write-Host "Electron ikili dosyasi indiriliyor..." -ForegroundColor DarkGray
    node node_modules/electron/install.js
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Electron)) { Fail "Electron indirilemedi. Internet baglantinizi kontrol edin." }
}

if ($Build) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "publish.ps1")
    if ($LASTEXITCODE -ne 0) { Fail "Exe uretimi basarisiz oldu." }
    exit 0
}
if ($Check -or $UiTest) {
    # better-sqlite3 13 N-API hazir ikiliyle gelir: Node (vitest) ve Electron ayni ikiliyi kullanir.
    $steps = if ($UiTest) { @("build", "test:e2e") } else { @("typecheck", "test", "build") }
    foreach ($step in $steps) {
        Write-Host "npm run $step" -ForegroundColor DarkGray
        npm run $step
        if ($LASTEXITCODE -ne 0) { Fail "npm run $step basarisiz (cikis kodu $LASTEXITCODE)." }
    }
    Write-Host "Tum kontroller gecti." -ForegroundColor Green
    exit 0
}
if ($Prod) {
    npm run start
    exit $LASTEXITCODE
}

$busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($busy) {
    $proc = Get-Process -Id $busy.OwningProcess -ErrorAction SilentlyContinue
    Fail "Port $Port baska bir islem tarafindan kullaniliyor ($($proc.ProcessName), PID $($busy.OwningProcess)). Uygulama zaten acik olabilir; o islemi kapatip tekrar deneyin."
}

Write-Host "Uygulama baslatiliyor (http://localhost:$Port)..." -ForegroundColor Green
npm run dev
exit $LASTEXITCODE
