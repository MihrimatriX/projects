#Requires -Version 5.1
<#
.SYNOPSIS
  Aliskanlik Takipcisi - tek tikla baslatici.
.PARAMETER Device
  Hedef cihaz kimligi (windows, chrome, edge veya "flutter devices" ciktisindaki id).
  Bos birakilirsa sirayla denenir: windows > chrome > edge.
.PARAMETER Check
  Sadece "flutter analyze" + "flutter test" calistirir ve cikar.
.EXAMPLE
  .\run.ps1
.EXAMPLE
  .\run.ps1 chrome
.EXAMPLE
  .\run.ps1 -Check
#>
param(
    [Parameter(Position = 0)][string]$Device,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host ''
Write-Host '  Aliskanlik Takipcisi' -ForegroundColor Cyan
Write-Host ''

# --- Flutter bul: PATH, sonra bilinen kurulum yerleri -----------------------
# WinGet'in ayri Dart SDK'si Flutter'in dart'i ile cakisir; PATH'ten cikar.
$env:Path = (($env:Path -split ';') | Where-Object { $_ -and $_ -notmatch 'WinGet\\Packages\\Google\.DartSDK' }) -join ';'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    foreach ($dir in @("$env:LOCALAPPDATA\flutter\bin", 'C:\flutter\bin', "$env:USERPROFILE\flutter\bin")) {
        if (Test-Path (Join-Path $dir 'flutter.bat')) { $env:Path = "$dir;$env:Path"; break }
    }
}
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host 'HATA: Flutter bulunamadi. PATH''e ekleyin ya da C:\flutter veya %LOCALAPPDATA%\flutter altina kurun.' -ForegroundColor Red
    Write-Host '      https://docs.flutter.dev/get-started/install/windows' -ForegroundColor Yellow
    exit 1
}
# dart da ayni SDK'dan gelsin
$env:Path = "$(Split-Path $flutterCmd.Source -Parent);$env:Path"

function Invoke-Flutter {
    & flutter @args
    if ($LASTEXITCODE -ne 0) { throw "flutter $($args -join ' ') basarisiz (kod $LASTEXITCODE)" }
}

# Visual Studio C++ ana surumu (orn. 17, 18) ya da $null
function Get-VsCppVersion {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $null }
    $ver = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion
    if ($ver) { return [int](("$ver").Split('.')[0]) }
    return $null
}

function Test-DeveloperMode {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
    return [bool]($key -and $key.AllowDevelopmentWithoutDevLicense -eq 1)
}

# Windows masaustu derlemesi: VS C++ gerekir; eklenti varsa Flutter symlink
# olusturur, bu da Gelistirici Modu ister.
function Test-WindowsReady {
    if (-not (Get-VsCppVersion)) {
        Write-Host 'Not: Visual Studio C++ (Desktop development with C++) yok; Windows hedefi atlandi.' -ForegroundColor DarkYellow
        return $false
    }
    if (Test-DeveloperMode) { return $true }
    $deps = '.flutter-plugins-dependencies'
    if ((Test-Path $deps) -and @((Get-Content $deps -Raw | ConvertFrom-Json).plugins.windows).Count -gt 0) {
        Write-Host 'Not: Windows masaustu icin Gelistirici Modu gerekli (start ms-settings:developers); Windows hedefi atlandi.' -ForegroundColor DarkYellow
        return $false
    }
    return $true
}

function Select-Device([string[]]$Order) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $json = (& flutter devices --machine 2>$null) -join "`n"
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) { throw "flutter devices basarisiz (kod $code)" }
    $ids = @(($json | ConvertFrom-Json).id)
    foreach ($id in $Order) {
        if ($ids -notcontains $id) { continue }
        if ($id -eq 'windows' -and -not (Test-WindowsReady)) { continue }
        return $id
    }
    throw "Uygun cihaz bulunamadi ($($Order -join ', ')). 'flutter doctor' ciktisini kontrol edin."
}

# --- Bagimliliklar: sadece pubspec degistiyse ------------------------------
$pkgConfig = '.dart_tool\package_config.json'
$stale = -not (Test-Path $pkgConfig)
if (-not $stale) {
    $stamp = (Get-Item $pkgConfig).LastWriteTime
    $stale = [bool](@('pubspec.yaml', 'pubspec.lock') | Where-Object { (Test-Path $_) -and (Get-Item $_).LastWriteTime -gt $stamp })
}
if ($stale) {
    Write-Host '>> Bagimliliklar (flutter pub get)' -ForegroundColor Yellow
    & flutter pub get
    # Gelistirici Modu kapaliyken ilk pub get symlink hatasi verir ama eklenti
    # listesini yazar; ikinci deneme web hedefleri icin temiz gecer.
    if ($LASTEXITCODE -ne 0) { Invoke-Flutter pub get }
    (Get-Item $pkgConfig).LastWriteTime = Get-Date
}

if ($Check) {
    Write-Host '>> Analiz + test' -ForegroundColor Yellow
    Invoke-Flutter analyze --no-fatal-infos
    Invoke-Flutter test
    Write-Host 'Kontroller basarili.' -ForegroundColor Green
    exit 0
}

if (-not $Device) { $Device = Select-Device @('windows', 'chrome', 'edge') }

if ($Device -eq 'windows') {
    # Baska bir Visual Studio surumuyle olusmus CMake onbellegi derlemeyi kirar.
    $cache = 'build\windows\x64\CMakeCache.txt'
    $vs = Get-VsCppVersion
    if ($vs -and (Test-Path $cache) -and -not (Select-String -Path $cache -Pattern "CMAKE_GENERATOR:INTERNAL=Visual Studio $vs " -Quiet)) {
        Write-Host '>> Eski CMake onbellegi temizleniyor' -ForegroundColor DarkGray
        Remove-Item -Recurse -Force 'build\windows\x64'
    }
}

Write-Host ">> Baslatiliyor ($Device)" -ForegroundColor Green
& flutter run -d $Device
exit $LASTEXITCODE
