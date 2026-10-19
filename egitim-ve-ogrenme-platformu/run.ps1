#Requires -Version 5.1
<#
.SYNOPSIS
  Ogrenim Pazari - tek tikla calistir: bagimliliklar, veritabani, dev sunucu.
  Adres: http://localhost:3101/
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File run.ps1
  powershell -ExecutionPolicy Bypass -File run.ps1 -NoBrowser
  powershell -ExecutionPolicy Bypass -File run.ps1 -Check   # tum testler (vitest, tsc, Playwright)
#>
param([switch]$NoBrowser, [switch]$Check)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

$Port = 3101
$Url = 'http://localhost:3101/'

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
Write-Host "  Ogrenim Pazari  ->  $Url" -ForegroundColor Green
Write-Host ""

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurup tekrar deneyin.'
}

# Port doluysa hicbir sureci kapatmayiz: uygulama zaten aciksa tarayiciyi acar, degilse hata veririz.
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener -and -not $Check) {
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

# SQLite veritabani ve Prisma istemcisi yalnizca sema degistiginde yenilenir.
if (Test-Stale 'prisma\schema.prisma' 'prisma\dev.db') {
    Write-Step 'Veritabani hazirlaniyor (prisma db push)'
    Invoke-Checked npx.cmd prisma db push
    (Get-Item 'prisma\dev.db').LastWriteTime = Get-Date
} elseif (Test-Stale 'prisma\schema.prisma' 'node_modules\.prisma\client\schema.prisma') {
    Write-Step 'Prisma istemcisi uretiliyor'
    Invoke-Checked npx.cmd prisma generate
}

if ($Check) {
    $env:CHECKPOINT_DISABLE = '1'
    Write-Step 'Birim + API testleri (vitest)'
    Invoke-Checked npm.cmd test
    Write-Step 'Tip denetimi (tsc)'
    Invoke-Checked npm.cmd run lint
    Write-Step 'Tarayici testleri (Playwright, prisma/e2e.db)'
    Invoke-Checked npx.cmd playwright install chromium
    Invoke-Checked npm.cmd run test:e2e
    Write-Host 'Tum testler gecti.' -ForegroundColor Green
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
