#Requires -Version 5.1
<#
.SYNOPSIS
    DevProjects.exe dosyasini repo kokune yazar (tek dosya, self-contained).

.EXAMPLE
    .\publish.ps1
#>
param(
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Project = Join-Path $PSScriptRoot "ProjeLauncher\ProjeLauncher.csproj"
$Staging = Join-Path $PSScriptRoot "dist\publish"
$OutExe = Join-Path $Root "DevProjects.exe"
$Rid = "win-x64"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error ".NET 10 SDK gerekli: https://dotnet.microsoft.com/download"
}

Set-Location $PSScriptRoot

if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Path $Staging -Force | Out-Null

Write-Host ">> DevProjects.exe paketleniyor ($Rid, self-contained)..." -ForegroundColor Cyan

dotnet publish $Project `
    -c Release `
    -r $Rid `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:PublishReadyToRun=true `
    -p:DebugType=none `
    -p:DebugSymbols=false `
    -o $Staging

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$built = Join-Path $Staging "DevProjects.exe"
if (-not (Test-Path $built)) { Write-Error "Derleme ciktisi yok: $built" }

Copy-Item $built $OutExe -Force
$mb = [math]::Round((Get-Item $OutExe).Length / 1MB, 1)

Write-Host ">> Hazir: $OutExe ($mb MB)" -ForegroundColor Green

if (-not $SkipSmoke) {
    Write-Host ">> Smoke test..." -ForegroundColor Cyan
    $p = Start-Process -FilePath $OutExe -WorkingDirectory $Root -PassThru
    # Pencere ~10 sn icinde acilmali ve ayakta kalmali.
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
        $p.Refresh()
        if ($p.MainWindowHandle -ne [IntPtr]::Zero -and $p.MainWindowTitle -eq 'DEV Projects') { break }
        Start-Sleep -Milliseconds 250
    }
    if ($p.HasExited) { Write-Error "DevProjects.exe hemen kapandi (exit $($p.ExitCode))" }
    if ($p.MainWindowTitle -ne 'DEV Projects') {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Error "DevProjects.exe ana penceresi acilmadi (baslik: '$($p.MainWindowTitle)')"
    }
    Start-Sleep -Seconds 3
    if ($p.HasExited) { Write-Error "DevProjects.exe acildiktan sonra kapandi (exit $($p.ExitCode))" }
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Write-Host ">> Smoke test OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Calistir: $OutExe" -ForegroundColor Gray
