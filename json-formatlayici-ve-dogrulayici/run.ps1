#Requires -Version 5.1
<#
.SYNOPSIS
  JSON Formatlayici ve Dogrulayici - tek tikla calistir: bagimliliklar, dev sunucu.
  Adres: http://localhost:3103/lab
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File run.ps1
  powershell -ExecutionPolicy Bypass -File run.ps1 -NoBrowser
  powershell -ExecutionPolicy Bypass -File run.ps1 -Check   # vitest + tsc + statik export
  powershell -ExecutionPolicy Bypass -File run.ps1 -UiTest  # Playwright: tum ekranlar (web) + Electron kabugu + paketli exe
#>
param([switch]$NoBrowser, [switch]$Check, [switch]$UiTest)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

$Port = 3103
$Url = 'http://localhost:3103/lab'

function Write-Step([string]$Message) { Write-Host ">> $Message" -ForegroundColor Cyan }
function Stop-WithError([string]$Message) { Write-Host "HATA: $Message" -ForegroundColor Red; exit 1 }
function Invoke-Checked {
    $exe, $rest = $args
    $rest = @($rest | Where-Object { $null -ne $_ }); & $exe @rest  # tek arguman string ise @rest karakterlere bolunurdu
    if ($LASTEXITCODE -ne 0) { Stop-WithError "'$($args -join ' ')' basarisiz oldu (cikis kodu $LASTEXITCODE)." }
}
function Test-Stale([string]$Source, [string]$Target) {
    -not (Test-Path $Target) -or (Get-Item $Source).LastWriteTime -gt (Get-Item $Target).LastWriteTime
}
function Test-AppResponds {
    try { $null = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 5; $true }
    catch { $null -ne $_.Exception.Response }
}

Write-Host ""
Write-Host "  JSON Formatlayici ve Dogrulayici  ->  $Url" -ForegroundColor Green
Write-Host ""

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurup tekrar deneyin.'
}

# Port doluysa hicbir sureci kapatmayiz: uygulama zaten aciksa tarayiciyi acar, degilse hata veririz.
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener -and -not $Check -and -not $UiTest) {
    if (Test-AppResponds) {
        Write-Step 'Uygulama zaten calisiyor.'
        if (-not $NoBrowser) { Start-Process $Url }
        exit 0
    }
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    Stop-WithError "Port $Port baska bir surec tarafindan kullaniliyor: PID $($listener.OwningProcess) ($($owner.ProcessName)). O sureci kapatip tekrar deneyin."
}
if (Test-Stale 'package-lock.json' 'node_modules\.package-lock.json') {
    Write-Step 'Bagimliliklar kuruluyor (npm ci)'
    & npm.cmd ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) {
        Write-Step 'npm ci basarisiz, npm install deneniyor'
        Invoke-Checked npm.cmd install --no-audit --no-fund
    }
}
if ($Check) {
    Write-Step 'Birim testleri (vitest)'
    Invoke-Checked npm.cmd test
    Write-Step 'Tip denetimi (tsc)'
    Invoke-Checked npm.cmd run lint
    Write-Step 'Statik export (out\)'
    Invoke-Checked npm.cmd run build:static
    Write-Host 'Tum kontroller gecti. Arayuz testleri icin: .\run.ps1 -UiTest' -ForegroundColor Green
    exit 0
}
if ($UiTest) {
    Write-Step 'Tarayici arayuz testleri (Playwright, tum ekranlar)'
    Invoke-Checked npx.cmd playwright install chromium
    Invoke-Checked npm.cmd run test:e2e
    Write-Step 'Statik export + Electron kabugu arayuz testi (pencere acar)'
    Invoke-Checked npm.cmd run build:static
    if (-not (Test-Path 'node_modules\electron\dist\electron.exe')) { Invoke-Checked node.exe node_modules\electron\install.js }
    Invoke-Checked npx.cmd playwright test -c playwright.electron.config.ts
    $exe = Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) "dist\$(Split-Path $PSScriptRoot -Leaf)") -Filter *.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) {
        Write-Step "Paketlenmis exe arayuz testi: $($exe.Name)"
        $env:DESKTOP_EXE = $exe.FullName
        try { Invoke-Checked npx.cmd playwright test -c playwright.electron.config.ts } finally { Remove-Item Env:DESKTOP_EXE }
    } else {
        Write-Host 'dist\ altinda exe yok; paketlenmis exe testi atlandi (.\publish.ps1 ile uretin).' -ForegroundColor Yellow
    }
    Write-Host 'Tum arayuz testleri gecti.' -ForegroundColor Green
    exit 0
}
if (-not $NoBrowser) {
    # Sunucu cevap verince tarayiciyi ac (en fazla ~60 sn bekler).
    $null = Start-Job -ArgumentList $Url -ScriptBlock {
        param($u)
        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline) {
            try { $null = Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 10; Start-Process $u; return }
            catch { if ($_.Exception.Response) { Start-Process $u; return } }
            Start-Sleep -Seconds 1
        }
    }
}

Write-Step "Dev sunucu baslatiliyor: $Url (durdurmak icin Ctrl+C)"
& npm.cmd run dev
exit $LASTEXITCODE
