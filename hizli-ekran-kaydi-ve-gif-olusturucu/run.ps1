#Requires -Version 5.1
<#
.SYNOPSIS
  Hizli Ekran Kaydi ve GIF Olusturucu - derler ve baslatir.
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

Write-Host '>>> Hizli Ekran Kaydi ve GIF Olusturucu' -ForegroundColor Cyan

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
}
try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
    Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
}

$config = if ($Release) { 'Release' } else { 'Debug' }
$exe = Join-Path $PSScriptRoot "EkranKaydi\bin\$config\net10.0-windows\EkranKaydi.exe"

if ($Check) {
    & dotnet test 'EkranKaydi.Tests\EkranKaydi.Tests.csproj' -c $config --nologo
    exit $LASTEXITCODE
}

if (-not (Test-Path 'assets\app.ico') -and (Test-Path 'scripts\generate-icon.ps1')) {
    Write-Host 'Ikonlar olusturuluyor...' -ForegroundColor DarkGray
    & powershell -NoProfile -ExecutionPolicy Bypass -File 'scripts\generate-icon.ps1'
    if ($LASTEXITCODE -ne 0) { Fail 'Ikon uretimi basarisiz.' }
}
foreach ($bin in 'ffmpeg.exe', 'ffprobe.exe') {
    if (-not (Test-Path "EkranKaydi\$bin")) {
        Write-Host "UYARI: EkranKaydi\$bin bulunamadi - PATH'te ffmpeg yoksa kayit calismaz. Kurulum: winget install Gyan.FFmpeg" -ForegroundColor Yellow
    }
}

# Uygulama zaten aciksa exe kilitlidir; yeniden derlemek yerine dogrudan baslat (tek-ornek uygulama one gelir).
if (Get-Process -Name 'EkranKaydi' -ErrorAction SilentlyContinue) { $NoBuild = $true }

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
# ponytail: yalnizca EkranKaydi\ ve assets\ altina bakar; baska yerdeki degisiklikte 'dotnet build' elle calistirin.
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'EkranKaydi', 'assets' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    Write-Host "Derleniyor ($config)..." -ForegroundColor DarkGray
    & dotnet build 'EkranKaydi\EkranKaydi.csproj' -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

Write-Host 'Baslatiliyor...' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)