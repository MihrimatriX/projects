#Requires -Version 5.1
<#
.SYNOPSIS
  Evrensel Uygulama ve Dosya Baslatici - derler ve baslatir.
.PARAMETER Release
  Release yapilandirmasiyla derler (varsayilan: Debug).
.PARAMETER NoBuild
  Derlemeyi atlar, mevcut exe'yi baslatir.
.PARAMETER Check
  Birim testleri + acilis duman testi (pencere acmaz).
.PARAMETER UiTest
  FlaUI arayuz testleri: gecici veri + sahte Baslat Menusu ile paleti acar (gercek uygulama baslatmaz).
#>
param([switch]$Release, [switch]$NoBuild, [switch]$Check, [switch]$UiTest)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "HATA: $Message" -ForegroundColor Red
    exit 1
}

Write-Host '>>> Evrensel Uygulama ve Dosya Baslatici' -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
}
try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
    Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
}

$config = if ($Release) { 'Release' } else { 'Debug' }
$exe = Join-Path $PSScriptRoot "UygulamaBaslatici\bin\$config\net10.0-windows\KomutPaleti.exe"

if ($Check -or $UiTest) {
    $filter = if ($UiTest) { 'Category=UI' } else { 'Category!=UI' }
    & dotnet test 'UygulamaBaslatici.Tests\UygulamaBaslatici.Tests.csproj' -c $config --nologo --filter $filter
    exit $LASTEXITCODE
}

# Uygulama zaten aciksa exe kilitlidir; yeniden derlemek yerine dogrudan baslat (tek-ornek uygulama one gelir).
if (Get-Process -Name 'KomutPaleti' -ErrorAction SilentlyContinue) { $NoBuild = $true }

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
# ponytail: yalnizca UygulamaBaslatici\ ve assets\ altina bakar; baska yerdeki degisiklikte 'dotnet build' elle calistirin.
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'UygulamaBaslatici', 'assets' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    Write-Host "Derleniyor ($config)..." -ForegroundColor DarkGray
    & dotnet build 'UygulamaBaslatici\UygulamaBaslatici.csproj' -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

Write-Host 'Baslatiliyor... (Alt+Space ile paleti acin)' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)