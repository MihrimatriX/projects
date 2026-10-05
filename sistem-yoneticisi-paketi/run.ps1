#Requires -Version 5.1
<#
.SYNOPSIS
  Sistem Yoneticisi Paketi - derler ve baslatir.
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

Write-Host '>>> Sistem Yoneticisi Paketi' -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
}
try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
    Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
}

$config = if ($Release) { 'Release' } else { 'Debug' }
$exe = Join-Path $PSScriptRoot "SistemYoneticisi\bin\$config\net10.0-windows\SistemYoneticisiPaketi.exe"

if ($Check) {
    & dotnet test 'SistemYoneticisi.Tests\SistemYoneticisi.Tests.csproj' -c $config --nologo
    exit $LASTEXITCODE
}
if (-not (Test-Path 'assets\icon.ico')) {
    $py = Get-Command python, py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py) {
        Write-Host 'Uygulama ikonu uretiliyor...' -ForegroundColor DarkGray
        & $py.Source 'scripts\gen_icon.py'
    } else {
        Write-Host 'Python yok - varsayilan exe ikonu kullanilacak.' -ForegroundColor Yellow
    }
}

# Uygulama zaten aciksa exe kilitlidir; yeniden derlemek yerine dogrudan baslat (tek-ornek uygulama one gelir).
if (Get-Process -Name 'SistemYoneticisiPaketi' -ErrorAction SilentlyContinue) { $NoBuild = $true }

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
# ponytail: yalnizca SistemYoneticisi\ ve assets\ altina bakar; baska yerdeki degisiklikte 'dotnet build' elle calistirin.
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'SistemYoneticisi', 'assets' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    Write-Host "Derleniyor ($config)..." -ForegroundColor DarkGray
    & dotnet build 'SistemYoneticisi\SistemYoneticisi.csproj' -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

Write-Host 'Baslatiliyor...' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)