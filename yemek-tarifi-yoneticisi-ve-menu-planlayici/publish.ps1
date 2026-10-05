#Requires -Version 5.1
<#
.SYNOPSIS
  Bagimsiz Windows surumu uretir: flutter build windows --release ciktisini
  <repo>\dist\<klasor-adi>\ altina kopyalar (ust duzeyde tek .exe).
.NOTES
  Flutter eklentileri Windows'ta sembolik baglanti ister; bu yuzden Windows
  Gelistirici Modu acik olmalidir. Kapaliysa betik net bir mesajla durur.
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$name = Split-Path $PSScriptRoot -Leaf
$repo = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $repo "dist\$name"

function Fail([string]$msg) {
    Write-Host "HATA: $msg" -ForegroundColor Red
    exit 1
}

# --- Flutter bul (run.ps1 ile ayni sira) -----------------------------------
$env:Path = (($env:Path -split ';') | Where-Object { $_ -and $_ -notmatch 'WinGet\\Packages\\Google\.DartSDK' }) -join ';'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    foreach ($dir in @("$env:LOCALAPPDATA\flutter\bin", 'C:\flutter\bin', "$env:USERPROFILE\flutter\bin")) {
        if (Test-Path (Join-Path $dir 'flutter.bat')) { $env:Path = "$dir;$env:Path"; break }
    }
}
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) { Fail 'Flutter bulunamadi. PATH''e ekleyin ya da C:\flutter altina kurun.' }
$env:Path = "$(Split-Path $flutterCmd.Source -Parent);$env:Path"

# --- On kosullar ------------------------------------------------------------
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsOk = $false
if (Test-Path $vswhere) {
    $vsOk = [bool](& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion)
}
if (-not $vsOk) {
    Fail 'Visual Studio C++ araclari (Desktop development with C++) bulunamadi; Windows derlemesi yapilamaz.'
}

$devKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
$devMode = [bool]($devKey -and $devKey.AllowDevelopmentWithoutDevLicense -eq 1)
$needsDevMode = $true
if (-not $devMode) {
    # Windows eklentisi yoksa symlink de gerekmez; eklenti listesine bak.
    $deps = '.flutter-plugins-dependencies'
    if (-not (Test-Path $deps)) {
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & flutter pub get 2>&1 | Out-Null
        $ErrorActionPreference = $old
    }
    if (Test-Path $deps) {
        $needsDevMode = @((Get-Content $deps -Raw | ConvertFrom-Json).plugins.windows).Count -gt 0
    }
}
if (-not $devMode -and $needsDevMode) {
    Write-Host ''
    Write-Host 'HATA: Windows Gelistirici Modu kapali.' -ForegroundColor Red
    Write-Host '  Flutter Windows eklentileri sembolik baglanti (symlink) gerektirir; bu mod' -ForegroundColor Yellow
    Write-Host '  kapaliyken "flutter build windows" basarisiz olur.' -ForegroundColor Yellow
    Write-Host '  Cozum: asagidaki komutu calistirin, "Gelistirici Modu" anahtarini acin ve' -ForegroundColor Yellow
    Write-Host '  bu betigi yeniden calistirin:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '      start ms-settings:developers' -ForegroundColor Cyan
    Write-Host ''
    exit 1
}

# --- Derleme ----------------------------------------------------------------
Write-Host '>> flutter pub get' -ForegroundColor Yellow
& flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get basarisiz (kod $LASTEXITCODE)" }

Write-Host '>> flutter build windows --release' -ForegroundColor Yellow
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { Fail "flutter build windows basarisiz (kod $LASTEXITCODE)" }

$release = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path $release)) { Fail "Derleme ciktisi bulunamadi: $release" }

# --- dist\<klasor> -----------------------------------------------------------
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $dist -Recurse -Force

$exes = @(Get-ChildItem -Path $dist -Filter '*.exe' -File)
if ($exes.Count -ne 1) { Fail "dist ust duzeyinde tam olarak bir .exe bekleniyordu, bulunan: $($exes.Count)" }

$sizeMb = [math]::Round(((Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host ''
Write-Host "Tamam: $($exes[0].FullName) (klasor $sizeMb MB)" -ForegroundColor Green
