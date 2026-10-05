param(
    [switch]$Sign,
    [string]$PfxPath = "",
    [string]$PfxPassword = "clipboard-dev"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$layoutDir = Join-Path $PSScriptRoot "packaging/layout"
$manifest = Join-Path $PSScriptRoot "packaging/AppxManifest.xml"
$outputMsix = Join-Path $PSScriptRoot "dist/ClipboardGecmisiYoneticisi.msix"
$publishDir = Join-Path (Split-Path $PSScriptRoot -Parent) ("dist\" + (Split-Path $PSScriptRoot -Leaf))

if (-not (Test-Path (Join-Path $publishDir "ClipboardGecmisiYoneticisi.exe"))) {
    Write-Host ">>> publish.ps1 calistiriliyor..." -ForegroundColor Yellow
    & "$PSScriptRoot\publish.ps1"
}

Write-Host ">>> MSIX layout hazirlaniyor..." -ForegroundColor Cyan
if (Test-Path $layoutDir) { Remove-Item $layoutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $layoutDir "Assets") | Out-Null

Copy-Item (Join-Path $publishDir "*") $layoutDir -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "releases/version.json") $layoutDir -Force
Copy-Item $manifest $layoutDir -Force

$pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
$bytes = [Convert]::FromBase64String($pngBase64)
foreach ($name in @("StoreLogo.png", "Square150x150Logo.png", "Square44x44Logo.png")) {
    [IO.File]::WriteAllBytes((Join-Path $layoutDir "Assets/$name"), $bytes)
}

$makeAppx = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\makeappx.exe",
    "${env:ProgramFiles}\Windows Kits\10\App Certification Kit\makeappx.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $makeAppx) {
    Write-Host "`n>>> MakeAppx bulunamadi (Windows SDK gerekli)." -ForegroundColor Yellow
    Write-Host "    Layout hazir: $layoutDir"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path $outputMsix -Parent) | Out-Null
if (Test-Path $outputMsix) { Remove-Item $outputMsix -Force }
& $makeAppx pack /d $layoutDir /p $outputMsix /o
if ($LASTEXITCODE -ne 0) { throw "MakeAppx basarisiz (kod $LASTEXITCODE)." }

Write-Host "`n>>> MSIX paketi: $outputMsix" -ForegroundColor Green

if ($Sign) {
    if ([string]::IsNullOrWhiteSpace($PfxPath)) {
        $PfxPath = Join-Path $PSScriptRoot "packaging/certs/dev-signing.pfx"
    }

    if (-not (Test-Path $PfxPath)) {
        Write-Host ">>> Sertifika yok, olusturuluyor..." -ForegroundColor Yellow
        & (Join-Path $PSScriptRoot "packaging/create-dev-cert.ps1")
    }

    $signTool = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\signtool.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $signTool) {
        Write-Host ">>> SignTool bulunamadi. Imzasiz paket birakildi." -ForegroundColor Yellow
        exit 0
    }

    Write-Host ">>> Imzalaniyor..." -ForegroundColor Cyan
    & $signTool sign /fd SHA256 /f $PfxPath /p $PfxPassword $outputMsix
    if ($LASTEXITCODE -ne 0) { throw "SignTool basarisiz (kod $LASTEXITCODE)." }
    Write-Host ">>> Imzali MSIX hazir." -ForegroundColor Green
    Write-Host "    Kurulum: .\install-msix.ps1"
}

Write-Host "    Gelistirici modu: Add-AppxPackage -Path `"$outputMsix`""
