#Requires -Version 5.1
<#
.SYNOPSIS
  Takim Iletisim ve Sohbet - bagimsiz masaustu surumu (Electron kabugu + Next standalone + paketli server.cjs).
  Cikti: <repo>\dist\takim-iletisim-ve-sohbet-araci\TakimSohbet.exe
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File publish.ps1
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

$Name = Split-Path -Leaf $PSScriptRoot
$Out = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\$Name"
$Desktop = Join-Path $PSScriptRoot 'desktop'
$Stage = Join-Path $Desktop 'stage'

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

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Node.js bulunamadi. https://nodejs.org adresinden LTS surumunu kurun.'
}
if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }

if (Test-Stale 'package-lock.json' 'node_modules\.package-lock.json') {
    Write-Step 'Bagimliliklar kuruluyor (npm ci)'
    Invoke-Checked npm.cmd ci --no-audit --no-fund
}

Write-Step 'Next.js derleniyor (standalone)'
Invoke-Checked npm.cmd run build

Write-Step 'Sunucu paketi hazirlaniyor'
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
Copy-Item '.next\standalone' $Stage -Recurse
Copy-Item '.next\static' (Join-Path $Stage '.next\static') -Recurse
Copy-Item 'public' (Join-Path $Stage 'public') -Recurse
# Gelistirme .env'i pakete girmez; tum ayarlar kabuk tarafindan verilir
Remove-Item (Join-Path $Stage '.env') -Force -ErrorAction SilentlyContinue

# Sunucu ve ilk acilis seed betigi tek dosyaya paketlenir (node_modules'taki Next/Prisma disarida kalir)
$external = '--external:next', '--external:@prisma/client', '--external:.prisma/client', '--external:bufferutil',
    '--external:utf-8-validate', '--external:@socket.io/redis-adapter', '--external:redis',
    '--external:@libsql/client', '--external:libsql'
Invoke-Checked npx.cmd esbuild server.ts --bundle --platform=node --format=cjs --target=node22 `
    "--outfile=$Stage\server.cjs" --log-level=warning @external
Invoke-Checked npx.cmd esbuild prisma/seed.ts --bundle --platform=node --format=cjs --target=node22 `
    "--outfile=$Stage\seed.cjs" --log-level=warning @external

# Yalnizca sema: demo kullanicilar ilk acilista kuruluma ozel rastgele anahtarla eklenir (desktop\main.cjs)
Write-Step 'Sablon veritabani olusturuluyor (bos sema)'
$oldDb = $env:DATABASE_URL
try {
    $env:DATABASE_URL = 'file:' + ((Join-Path $Stage 'template.db') -replace '\\', '/')
    Invoke-Checked npx.cmd prisma db push
} finally {
    $env:DATABASE_URL = $oldDb
}

Write-Step 'Electron kabugu paketleniyor'
Push-Location $Desktop
try {
    if (Test-Stale 'package-lock.json' 'node_modules\.package-lock.json') {
        Invoke-Checked npm.cmd ci --no-audit --no-fund
    }
    # npm 12 kurulum betiklerini engelleyebilir; Electron ikili dosyasi yoksa elle indir
    if (-not (Test-Path 'node_modules\electron\dist\electron.exe')) {
        Invoke-Checked node node_modules\electron\install.js
    }
    if (Test-Path 'out') { Remove-Item 'out' -Recurse -Force }
    Invoke-Checked npx.cmd electron-builder --win dir
} finally {
    Pop-Location
}

Write-Step "Cikti kopyalaniyor: $Out"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item (Join-Path $Desktop 'out\win-unpacked\*') $Out -Recurse
# Sunucu dosyalari (node_modules ve .next dahil) asar disinda durur; kabuk buradan baslatir
Copy-Item $Stage (Join-Path $Out 'resources\server') -Recurse

$exes = @(Get-ChildItem $Out -Filter '*.exe' -File)
if ($exes.Count -ne 1) { Stop-WithError "Cikti klasorunde tam olarak bir exe bekleniyordu, $($exes.Count) bulundu." }
$size = (Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ""
Write-Host ("Hazir: {0} (klasor {1:N0} MB)" -f $exes[0].FullName, $size) -ForegroundColor Green
Write-Host "Veriler: %APPDATA%\Takim Sohbet (ilk acilista demo: mehmet@acme.local / demo1234)"
