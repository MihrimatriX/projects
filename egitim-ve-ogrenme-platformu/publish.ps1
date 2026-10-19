#Requires -Version 5.1
<#
.SYNOPSIS
  Ogrenim Pazari - bagimsiz masaustu surumu (Electron kabugu + Next standalone sunucu + Prisma/SQLite).
  Cikti: <repo>\dist\egitim-ve-ogrenme-platformu\OgrenimPazari.exe
  Veriler: %APPDATA%\Ogrenim Pazari\ogrenim.db (ilk acilista bos sablondan kopyalanir)
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
$env:CHECKPOINT_DISABLE = '1'

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
if (Test-Stale 'package-lock.json' 'node_modules\.package-lock.json') {
    Write-Step 'Bagimliliklar kuruluyor (npm ci)'
    Invoke-Checked npm.cmd ci --no-audit --no-fund
}

Write-Step 'Birim testleri'
Invoke-Checked npm.cmd test

Write-Step 'Next.js derleniyor (standalone)'
$env:NEXT_STANDALONE = '1'
try { Invoke-Checked npm.cmd run build } finally { Remove-Item Env:NEXT_STANDALONE }
if (-not (Test-Path '.next\standalone\server.js')) { Stop-WithError '.next\standalone\server.js olusmadi.' }
if (-not (Test-Path '.next\standalone\node_modules\.prisma\client\query_engine-windows.dll.node')) {
    Stop-WithError 'Prisma query engine standalone ciktisina girmedi.'
}

Write-Step 'Sunucu paketi hazirlaniyor'
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
Copy-Item '.next\standalone' $Stage -Recurse
Copy-Item '.next\static' (Join-Path $Stage '.next\static') -Recurse
Copy-Item 'public' (Join-Path $Stage 'public') -Recurse
Write-Step 'Sablon veritabani olusturuluyor (bos sema; demo kurs ilk acilista eklenir)'
Invoke-Checked node.exe scripts\create-db.mjs (Join-Path $Stage 'template.db')

Write-Step 'Electron kabugu paketleniyor'
Push-Location $Desktop
try {
    if (Test-Stale 'package-lock.json' 'node_modules\.package-lock.json') {
        Invoke-Checked npm.cmd ci --no-audit --no-fund
    }
    # npm 12 kurulum betiklerini engelleyebilir; Electron ikili dosyasi yoksa elle indir
    if (-not (Test-Path 'node_modules\electron\dist\electron.exe')) {
        Invoke-Checked node.exe node_modules\electron\install.js
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

Write-Step 'Paketlenmis exe dogrulaniyor (gecici veri klasoruyle acilis + ders tamamlama)'
$env:DESKTOP_EXE = $exes[0].FullName
try { Invoke-Checked npx.cmd playwright test -c playwright.electron.config.ts } finally { Remove-Item Env:DESKTOP_EXE }

$size = (Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ""
Write-Host ("Hazir: {0} (klasor {1:N0} MB)" -f $exes[0].FullName, $size) -ForegroundColor Green
Write-Host "Veriler: %APPDATA%\Ogrenim Pazari\ogrenim.db"
