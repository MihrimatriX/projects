#Requires -Version 5.1
<#
.SYNOPSIS
  Bagimsiz Windows surumu uretir: <repo>\dist\json-formatlayici-ve-dogrulayici\
  (Next.js statik export + Electron kabugu; tek .exe, Node/Rust gerekmez).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File publish.ps1
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

function Stop-WithError([string]$Message) { Write-Host "HATA: $Message" -ForegroundColor Red; exit 1 }
function Invoke-Checked {
    $exe, $rest = $args
    $rest = @($rest | Where-Object { $null -ne $_ }); & $exe @rest  # tek arguman string ise @rest karakterlere bolunurdu
    if ($LASTEXITCODE -ne 0) { Stop-WithError "'$($args -join ' ')' basarisiz oldu (cikis kodu $LASTEXITCODE)." }
}

$name = Split-Path $PSScriptRoot -Leaf
$out = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\$name"
$unpacked = Join-Path $PSScriptRoot 'release\win-unpacked'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Stop-WithError 'Node.js bulunamadi.' }
if (-not (Test-Path 'node_modules\electron-builder')) {
    Write-Host '>> Bagimliliklar kuruluyor (npm ci)' -ForegroundColor Cyan
    Invoke-Checked npm.cmd ci --no-audit --no-fund
}

Write-Host '>> Birim testleri' -ForegroundColor Cyan
Invoke-Checked npm.cmd test
Write-Host '>> Statik export (out\)' -ForegroundColor Cyan
Invoke-Checked npm.cmd run build:static
if (-not (Test-Path 'out\lab.html')) { Stop-WithError 'out\lab.html olusmadi.' }

Write-Host '>> Electron paketleme (electron-builder --win dir)' -ForegroundColor Cyan
if (Test-Path $unpacked) { Remove-Item $unpacked -Recurse -Force }
Invoke-Checked npx.cmd electron-builder --win dir
if (-not (Test-Path $unpacked)) { Stop-WithError 'release\win-unpacked olusmadi.' }

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item (Join-Path $unpacked '*') $out -Recurse -Force

$exes = @(Get-ChildItem $out -Filter *.exe -File)
if ($exes.Count -ne 1) { Stop-WithError "Cikti klasorunde tam olarak bir .exe bekleniyordu, bulunan: $($exes.Count)." }
# signAndEditExecutable=false (Gelistirici Modu kapali): ikon ve surum bilgisi rcedit ile yazilir.
# Yeni exe kisa sure virus tarayicisi tarafindan kilitlenebilir; birkac kez denenir.
$rcedit = Join-Path $PSScriptRoot 'node_modules\rcedit\bin\rcedit-x64.exe'
if (-not (Test-Path $rcedit)) { Stop-WithError 'rcedit bulunamadi (npm install calistirin).' }
$version = (Get-Content 'package.json' -Raw | ConvertFrom-Json).version
$ok = $false
for ($i = 1; $i -le 5 -and -not $ok; $i++) {
    & $rcedit $exes[0].FullName --set-icon 'assets\app.ico' --set-file-version $version --set-product-version $version `
        --set-version-string ProductName 'JSON Formatlayici' --set-version-string FileDescription 'JSON Formatlayici ve Dogrulayici'
    $ok = ($LASTEXITCODE -eq 0)
    if (-not $ok) { Start-Sleep -Seconds 3 }
}
if (-not $ok) { Stop-WithError 'rcedit ile exe ikonu/surum bilgisi yazilamadi.' }
$sizeMb = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host ''
Write-Host "Hazir: $($exes[0].FullName) ($sizeMb MB)" -ForegroundColor Green
