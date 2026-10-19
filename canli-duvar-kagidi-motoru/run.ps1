#Requires -Version 5.1
<#
.SYNOPSIS
  Canli Duvar Kagidi Motoru - derler ve baslatir.
.DESCRIPTION
  WinUI 3 kabugu paketsiz (unpackaged) ve Windows App SDK'si gomulu (self-contained)
  derlenir; boylece Gelistirici Modu ya da ayri bir Windows App Runtime kurulumu gerekmez.
  dist\ altinda yayinlanmis tek exe varsa (build\publish.ps1) o kullanilir.
.PARAMETER Release
  Release yapilandirmasiyla derler (varsayilan: Debug).
.PARAMETER NoBuild
  Derlemeyi atlar, mevcut exe'yi baslatir.
.PARAMETER Check
  Birim testlerini calistirir; ardindan uygulamayi gecici bir veri klasoruyle acip
  ~10 sn ayakta kaldigini ve ilk acilis kurulumunu bitirdigini dogrular (duman testi).
.PARAMETER UiTest
  Uygulamayi derler ve FlaUI (UIA3) arayuz testlerini calistirir (tests\CanliDuvarKagidi.UiTests).
  Pencere acar; gecici veri klasoru + CANLI_DUVAR_UITEST=1 kullanir: masaustu duvar kagidi ve
  "Windows ile baslat" kayit anahtari degismez. Klavye kisayolu testi ortak .gui.lock kilidini alir.
#>
param([switch]$Release, [switch]$NoBuild, [switch]$Check, [switch]$UiTest)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "HATA: $Message" -ForegroundColor Red
    exit 1
}

Write-Host '>>> Canli Duvar Kagidi Motoru' -ForegroundColor Cyan

$config = if ($Release) { 'Release' } else { 'Debug' }
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'x64' }
$exe = Join-Path $PSScriptRoot "src\CanliDuvarKagidi.Shell\bin\$arch\$config\net10.0-windows10.0.26100.0\win-$($arch.ToLowerInvariant())\CanliDuvarKagidi.exe"

if ($Check) {
    Write-Host 'Birim testleri calisiyor...' -ForegroundColor DarkGray
    & dotnet test --project 'tests\CanliDuvarKagidi.Core.Tests\CanliDuvarKagidi.Core.Tests.csproj' --no-progress
    if ($LASTEXITCODE -ne 0) { Fail 'Testler basarisiz.' }
    if (Get-Process -Name 'CanliDuvarKagidi' -ErrorAction SilentlyContinue) {
        Write-Host 'Uygulama zaten acik; acilis duman testi atlandi (kapatip tekrar deneyin).' -ForegroundColor Yellow
        exit 0
    }
}

# Yayinlanmis surum (dist\) varsa ve kaynak derlenmemisse dogrudan onu ac.
$dist = Join-Path $PSScriptRoot 'dist\app\CanliDuvarKagidi.exe'
if (-not $Check -and (Test-Path $dist) -and -not (Test-Path $exe)) { $exe = $dist; $NoBuild = $true }

# Uygulama zaten aciksa exe kilitlidir; yeniden derlemek yerine dogrudan baslat.
if (Get-Process -Name 'CanliDuvarKagidi' -ErrorAction SilentlyContinue) { $NoBuild = $true }

# Kaynaklar exe'den yeni degilse derlemeyi atla (hizli acilis).
if (-not $NoBuild -and (Test-Path $exe)) {
    $built = (Get-Item $exe).LastWriteTimeUtc
    $changed = Get-ChildItem 'src', 'catalog' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.LastWriteTimeUtc -gt $built } |
        Select-Object -First 1
    if (-not $changed) { $NoBuild = $true }
}

if (-not $NoBuild) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Fail '.NET SDK bulunamadi. .NET 10 SDK kurun: https://dotnet.microsoft.com/download/dotnet/10.0'
    }
    try { $sdk = "$(& dotnet --version)".Trim() } catch { $sdk = '' }
    if ($sdk -notmatch '^(\d+)\.' -or [int]$Matches[1] -lt 10) {
        Fail ".NET 10 SDK gerekli (bulunan: '$sdk'). https://dotnet.microsoft.com/download/dotnet/10.0"
    }
    Write-Host "Derleniyor ($config, $arch)..." -ForegroundColor DarkGray
    & dotnet build 'src\CanliDuvarKagidi.Shell\CanliDuvarKagidi.Shell.csproj' -c $config "-p:Platform=$arch" `
        -p:WindowsPackageType=None -p:WindowsAppSDKSelfContained=true --nologo -v q -clp:ErrorsOnly
    if ($LASTEXITCODE -ne 0) { Fail 'Derleme basarisiz.' }
}

if (-not (Test-Path $exe)) { Fail "Derleme ciktisi bulunamadi: $exe" }

if ($UiTest) {
    Write-Host 'Arayuz testleri (FlaUI) calisiyor; pencere acilip kapanacak...' -ForegroundColor DarkGray
    $env:CDK_UITEST_EXE = $exe
    try {
        & dotnet test --project 'tests\CanliDuvarKagidi.UiTests\CanliDuvarKagidi.UiTests.csproj' --no-progress
        $code = $LASTEXITCODE
    } finally {
        Remove-Item Env:\CDK_UITEST_EXE -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) { Fail 'Arayuz testleri basarisiz.' }
    Write-Host 'OK: arayuz testleri gecti.' -ForegroundColor Green
    exit 0
}

if ($Check) {
    # Gercek kullanici verisine dokunmamak icin gecici veri klasoru (AppPaths: CANLI_DUVAR_DATA)
    $data = Join-Path $env:TEMP "cdk-duman-$PID"
    $env:CANLI_DUVAR_DATA = $data
    try {
        Write-Host 'Acilis duman testi (10 sn)...' -ForegroundColor DarkGray
        $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent) -PassThru
        Start-Sleep -Seconds 10
        $alive = -not $proc.HasExited
        $initialized = Test-Path (Join-Path $data '.initialized')
        if ($alive) { Stop-Process -Id $proc.Id -Force }
    } finally {
        Remove-Item Env:\CANLI_DUVAR_DATA -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
    Remove-Item $data -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $alive) { Fail "Uygulama acilista kapandi (cikis kodu: $($proc.ExitCode))." }
    if (-not $initialized) { Fail 'Ilk acilis kurulumu 10 sn icinde tamamlanmadi.' }
    Write-Host 'OK: testler ve acilis duman testi gecti.' -ForegroundColor Green
    exit 0
}

Write-Host 'Baslatiliyor (sistem tepsisinde de calisir)...' -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent)
