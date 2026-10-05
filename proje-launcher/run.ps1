#Requires -Version 5.1
<#
.SYNOPSIS
    Proje Launcher (DevProjects) - kaynaktan derler ve acar; testleri calistirir.
.PARAMETER Release
    Release yapilandirmasiyla derler (varsayilan: Debug).
.PARAMETER NoBuild
    Derlemeyi atlar, mevcut ciktiyi acar.
.PARAMETER Check
    Birim testleri (katalog, arama, durum, baslatma, view model). Pencere acmaz.
.PARAMETER UiTest
    FlaUI arayuz testleri: sahte repo kokunde gercek pencereyi acar (gercek projeleri baslatmaz).
#>
param(
    [switch]$Release,
    [switch]$NoBuild,
    [switch]$Check,
    [switch]$UiTest
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Project = Join-Path $Root "ProjeLauncher\ProjeLauncher.csproj"
$Tests = Join-Path $Root "ProjeLauncher.Tests\ProjeLauncher.Tests.csproj"
Set-Location $Root

function Write-Step([string]$Message) {
    Write-Host ">> $Message" -ForegroundColor Cyan
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "HATA: .NET 10 SDK gerekli: https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

$config = if ($Release) { "Release" } else { "Debug" }

if ($Check -or $UiTest) {
    Write-Step "Testler derleniyor ($config)..."
    & dotnet build $Tests -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $filter = if ($UiTest) { "--filter-trait" } else { "--filter-not-trait" }
    Write-Step $(if ($UiTest) { "Arayuz testleri (FlaUI)..." } else { "Birim testleri..." })
    & dotnet test --project $Tests -c $config --no-build $filter "Category=UI"
    exit $LASTEXITCODE
}

$exePath = Join-Path $Root "ProjeLauncher\bin\$config\net10.0-windows\DevProjects.exe"

if (-not $NoBuild) {
    Write-Step "Derleniyor ($config)..."
    & dotnet build $Project -c $config --nologo -v q
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Step "Baslatiliyor..."
Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent)
