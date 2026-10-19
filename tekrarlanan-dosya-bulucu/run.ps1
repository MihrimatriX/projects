#Requires -Version 5.1
<#
.SYNOPSIS
  Tekrarlanan Dosya Bulucu - tek tik baslatici (venv + bagimliliklar + uygulama).
.EXAMPLE
  .\run.ps1            # uygulamayi baslat (ek argumanlar main.py'ye gecer)
  .\run.ps1 -Check     # bagimliliklari kur ve testleri calistir
  .\run.ps1 -UiTest    # pytest-qt arayuz testleri (gercek pencereler)
#>
param(
    [switch]$Check,
    [switch]$UiTest,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$AppArgs = @()
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">>> Tekrarlanan Dosya Bulucu" -ForegroundColor Cyan

# Native komutlar stderr'e yazinca PS 5.1 'Stop' ile patlamasin; cikis kodu $LASTEXITCODE'dan okunur.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $ErrorActionPreference = "Continue"
    & $Exe @Arguments
}

function Test-Python([string[]]$Cmd) {
    if (-not (Get-Command $Cmd[0] -ErrorAction SilentlyContinue)) { return $false }
    try {
        $extra = @($Cmd | Select-Object -Skip 1)
        Invoke-Native $Cmd[0] ($extra + @("-c", "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)")) *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Find-SystemPython {
    $candidates = @()
    foreach ($v in 14, 13, 12, 11) {
        $p = Join-Path $env:LOCALAPPDATA "Programs\Python\Python3$v\python.exe"
        if (Test-Path $p) { $candidates += , @($p) }
    }
    if (Get-Command py -ErrorAction SilentlyContinue) { $candidates += , @("py", "-3") }
    foreach ($name in "python3", "python") {
        Get-Command $name -CommandType Application -All -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notmatch "WindowsApps" } |
            ForEach-Object { $candidates += , @($_.Source) }
    }
    foreach ($c in $candidates) { if (Test-Python $c) { return , $c } }
    return $null
}

$venvDir = Join-Path $PSScriptRoot ".venv"
$py = Join-Path $venvDir "Scripts\python.exe"
$stamp = Join-Path $venvDir ".requirements.sha256"

if ((Test-Path $venvDir) -and -not (Test-Python @($py))) {
    Write-Host "Bozuk sanal ortam bulundu, yeniden olusturuluyor..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $venvDir
}
if (-not (Test-Path $py)) {
    $sys = Find-SystemPython
    if (-not $sys) {
        Write-Host "HATA: Python 3.11+ bulunamadi." -ForegroundColor Red
        Write-Host "  Kurulum: winget install Python.Python.3.13" -ForegroundColor Yellow
        Write-Host "  (Microsoft Store 'python' kisayolu desteklenmez.)" -ForegroundColor DarkGray
        exit 1
    }
    Write-Host "Sanal ortam olusturuluyor (.venv)..." -ForegroundColor Yellow
    Invoke-Native $sys[0] (@($sys | Select-Object -Skip 1) + @("-m", "venv", $venvDir))
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $py)) {
        Write-Host "HATA: Sanal ortam olusturulamadi." -ForegroundColor Red
        exit 1
    }
}

# .NET ile hash: Get-FileHash, pwsh 7 icinden cagrilan powershell.exe'de yuklenemeyebiliyor.
$sha = [Security.Cryptography.SHA256]::Create()
$reqHash = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "requirements.txt"))))
$oldHash = if (Test-Path $stamp) { (Get-Content $stamp -Raw).Trim() } else { "" }
if ($reqHash -ne $oldHash) {
    Write-Host "Bagimliliklar kuruluyor..." -ForegroundColor Yellow
    Invoke-Native $py @("-m", "pip", "install", "--disable-pip-version-check", "-q", "-r", "requirements.txt")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "HATA: Bagimliliklar kurulamadi (pip cikis kodu $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
    Set-Content -Path $stamp -Value $reqHash -Encoding ASCII
}

if ($Check -or $UiTest) {
    Invoke-Native $py @("-c", "import pytest, pytestqt") *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Native $py @("-m", "pip", "install", "--disable-pip-version-check", "-q", "-r", "requirements-dev.txt")
        if ($LASTEXITCODE -ne 0) { Write-Host "HATA: test bagimliliklari kurulamadi." -ForegroundColor Red; exit 1 }
    }
    if ($UiTest) {
        # Gercek pencereler (Windows QPA); masaustu ortak kilidi testlerin icinde alinir.
        $env:QT_QPA_PLATFORM = "windows"
        Invoke-Native $py @("-m", "pytest", "-q", "tests/ui")
    } else {
        Invoke-Native $py @("-m", "pytest", "-q", "--ignore=tests/ui")
    }
    exit $LASTEXITCODE
}

# Takili kalmis eski oturumlari kapat
Invoke-Native $py @("-c", "from utils.process_guard import kill_stale_instances; kill_stale_instances()")

Write-Host "Uygulama baslatiliyor..." -ForegroundColor Green
Invoke-Native $py (@("main.py") + $AppArgs)
exit $LASTEXITCODE
