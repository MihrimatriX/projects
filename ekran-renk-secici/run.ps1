#Requires -Version 5.1
<#
.SYNOPSIS
  Ekran Renk Secici - derler ve baslatir.
.PARAMETER Release
  Release yapilandirmasiyla derler (varsayilan: Debug).
.PARAMETER NoBuild
  Derlemeyi atlar, mevcut exe'yi baslatir.
.PARAMETER Check
  Birim testleri + acilis duman testi (pencere acmaz; gecici veri klasoru).
.PARAMETER UiTest
  FlaUI arayuz testleri: gercek pencereyi gecici veri klasoruyle acar, panoyu sonra geri yukler.
#>
param([switch]$Release, [switch]$NoBuild, [switch]$Check, [switch]$UiTest)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "HATA: $Message" -ForegroundColor Red
    exit 1
}

Write-Host '>>> Ekran Renk Secici' -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
}
try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
    Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
}

$config = if ($Release) { 'Release' } else { 'Debug' }
$exe = Join-Path $PSScriptRoot "EkranRenkSecici\bin\$config\net10.0-windows\EkranRenkSecici.exe"

if ($Check -or $UiTest) {
    $filter = if ($UiTest) { 'Category=UI' } else { 'Category!=UI' }
    & dotnet test 'EkranRenkSecici.Tests\EkranRenkSecici.Tests.csproj' -c $config --nologo --filter $filter
    exit $LASTEXITCODE
}

if (-not (Test-Path 'assets\app.ico') -and (Test-Path 'scripts\generate-assets.ps1')) {
    Write-Host 'Ikonlar olusturuluyor...' -ForegroundColor DarkGray
    & powershell -NoProfile -ExecutionPolicy Bypass -File 'scripts\generate-assets.ps1'
    if ($LASTEXITCODE -ne 0) { Fail 'Ikon uretimi basarisiz.' }
}

# Uygulama zaten aciksa exe kilitlidir; yeniden derlemek yerine dogrudan baslat (tek-ornek uygulama one gelir).
if (Get-Process -Name 'EkranRenkSecici' -ErrorAction SilentlyContinue) { $NoBuild = $true }

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
# ponytail: yalnizca EkranRenkSecici\ ve assets\ altina bakar; baska yerdeki degisiklikte 'dotnet build' elle calistirin.
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'EkranRenkSecici', 'assets' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    Write-Host "Derleniyor ($config)..." -ForegroundColor DarkGray
    & dotnet build 'EkranRenkSecici\EkranRenkSecici.csproj' -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

Write-Host 'Baslatiliyor...' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)