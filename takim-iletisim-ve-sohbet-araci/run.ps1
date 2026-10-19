#Requires -Version 5.1
<#
.SYNOPSIS
  Takim Iletisim ve Sohbet - tek tikla calistir: bagimliliklar, veritabani, dev sunucu.
  Adres: http://localhost:3106/
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File run.ps1
  powershell -ExecutionPolicy Bypass -File run.ps1 -NoBrowser
  powershell -ExecutionPolicy Bypass -File run.ps1 -Check   # Vitest + tip kontrolu + Playwright e2e (ana akislar)
  powershell -ExecutionPolicy Bypass -File run.ps1 -UiTest  # arayuz envanteri (tum ekranlar, cok kullanici) + Electron kabugu
  Testler gecici klasorde ayri bir veritabani ve 3196 portu kullanir; prisma\dev.db'ye dokunulmaz.
#>
param([switch]$NoBrowser, [switch]$Check, [switch]$UiTest)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

$Port = 3106
$Url = 'http://localhost:3106/'

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
Write-Host "  Takim Iletisim ve Sohbet  ->  $Url" -ForegroundColor Green
Write-Host ""

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurup tekrar deneyin.'
}

# Port doluysa hicbir sureci kapatmayiz: uygulama zaten aciksa tarayiciyi acar, degilse hata veririz.
$listener = if ($Check -or $UiTest) { $null } else { Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 }
if ($listener) {
    if (Test-AppResponds) {
        Write-Step 'Uygulama zaten calisiyor.'
        if (-not $NoBrowser) { Start-Process $Url }
        exit 0
    }
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    Stop-WithError "Port $Port baska bir surec tarafindan kullaniliyor: PID $($listener.OwningProcess) ($($owner.ProcessName)). O sureci kapatip tekrar deneyin."
}

if (-not (Test-Path '.env')) {
    Copy-Item '.env.example' '.env'
    Write-Step '.env olusturuldu (.env.example kopyalandi)'
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
    Write-Step 'Demo veriler yukleniyor (giris: mehmet@acme.local / demo1234)'
    Invoke-Checked npm.cmd run db:seed
} elseif (Test-Stale 'prisma\schema.prisma' 'node_modules\.prisma\client\schema.prisma') {
    Write-Step 'Prisma istemcisi uretiliyor'
    Invoke-Checked npx.cmd prisma generate
}

if ($Check) {
    Write-Step 'Birim testleri (vitest)'
    Invoke-Checked npm.cmd test
    Write-Step 'Tip kontrolu (tsc)'
    Invoke-Checked npm.cmd run lint
    Write-Step 'E2E testleri (Playwright; uretim derlemesi + gecici veritabani, port 3196)'
    Invoke-Checked npx.cmd playwright install chromium
    Invoke-Checked npx.cmd playwright test --project=e2e
    Write-Host 'Tum testler gecti.' -ForegroundColor Green
    exit 0
}

if ($UiTest) {
    # Electron testi publish.ps1'in hazirladigi desktop\stage'i kullanir; yoksa atlanir
    Write-Step 'Arayuz testleri (Playwright: tum ekranlar + cok kullanicili anlik akis + Electron kabugu)'
    Invoke-Checked npx.cmd playwright install chromium
    Invoke-Checked npx.cmd playwright test --project=ui --project=electron
    Write-Host 'Arayuz testleri gecti.' -ForegroundColor Green
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
