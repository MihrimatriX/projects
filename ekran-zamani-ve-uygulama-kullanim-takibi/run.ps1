#Requires -Version 5.1
<#
.SYNOPSIS
  Ekran Zamani - derler ve baslatir (Ctrl+Shift+E ile panel).
.DESCRIPTION
  WinUI 3 uygulamasi paketsiz (unpackaged) ve Windows App SDK'si gomulu (self-contained)
  derlenir; boylece Gelistirici Modu ya da ayri bir Windows App Runtime kurulumu gerekmez.
.PARAMETER Release
  Release yapilandirmasiyla derler (varsayilan: Debug).
.PARAMETER NoBuild
  Derlemeyi atlar, mevcut exe'yi baslatir.
.PARAMETER Check
  Yalnizca testleri calistirir ve cikar (uygulamayi baslatmaz).
#>
param([switch]$Release, [switch]$NoBuild, [switch]$Check)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "HATA: $Message" -ForegroundColor Red
    exit 1
}

Write-Host '>>> Ekran Zamani (Ctrl+Shift+E ile paneli ac)' -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
}
try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
    Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
}

$config = if ($Release) { 'Release' } else { 'Debug' }
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'x64' }
$proj = 'windows\EkranZamani.WinUI\EkranZamani.WinUI.csproj'
$exe = Join-Path $PSScriptRoot "windows\EkranZamani.WinUI\bin\$arch\$config\net10.0-windows10.0.26100.0\win-$($arch.ToLowerInvariant())\EkranZamani.WinUI.exe"

if ($Check) {
    & dotnet test 'EkranZamani.Tests\EkranZamani.Tests.csproj' -c $config --nologo
    exit $LASTEXITCODE
}

if (-not (Test-Path 'windows\EkranZamani.WinUI\Assets\AppIcon.ico')) {
    Write-Host 'Ikonlar olusturuluyor...' -ForegroundColor DarkGray
    & powershell -NoProfile -ExecutionPolicy Bypass -File 'generate-assets.ps1'
    if ($LASTEXITCODE -ne 0) { Fail 'Ikon uretimi basarisiz.' }
}

# Ayni anda iki takipci calismasin: acik ornegi kapat (exe kilidi de kalkar).
Get-Process -Name 'EkranZamani.WinUI' -ErrorAction SilentlyContinue | Stop-Process -Force

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'windows\EkranZamani.WinUI', 'EkranZamani.Core' -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    Write-Host "Derleniyor ($config, $arch)..." -ForegroundColor DarkGray
    & dotnet build $proj -c $config "-p:Platform=$arch" -p:WindowsPackageType=None -p:WindowsAppSDKSelfContained=true `
        --nologo -v q -clp:ErrorsOnly
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

Write-Host 'Baslatiliyor...' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)
