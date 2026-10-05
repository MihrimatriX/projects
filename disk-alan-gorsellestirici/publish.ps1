#Requires -Version 5.1
<#
.SYNOPSIS
  Disk Alani Gorsellestirici - bagimsiz exe (PyInstaller --onedir --windowed, DiskAlanGorsellestirici.spec).
  Cikti: <repo>\dist\disk-alan-gorsellestirici\DiskAlanGorsellestirici.exe
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">>> Disk Alani Gorsellestirici - EXE derlemesi" -ForegroundColor Cyan

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $ErrorActionPreference = "Continue"
    & $Exe @Arguments
}

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    # run.ps1 -Check venv'i olusturur ve bagimliliklari kurar.
    Invoke-Native "powershell.exe" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "run.ps1"), "-Check")
    if (-not (Test-Path $py)) { Write-Host "HATA: Sanal ortam hazirlanamadi." -ForegroundColor Red; exit 1 }
}

Write-Host "Derleme bagimliliklari yukleniyor..." -ForegroundColor DarkGray
Invoke-Native $py @("-m", "pip", "install", "--disable-pip-version-check", "-q", "-r", "requirements.txt", "-r", "requirements-dev.txt", "pyinstaller>=6.22")
if ($LASTEXITCODE -ne 0) { Write-Host "HATA: pip install basarisiz." -ForegroundColor Red; exit 1 }

Write-Host ">>> Testler calistiriliyor..." -ForegroundColor Cyan
Invoke-Native $py @("-m", "pytest", "-q", "--ignore=tests/ui")
if ($LASTEXITCODE -ne 0) { Write-Host "HATA: Testler basarisiz, exe uretilmedi." -ForegroundColor Red; exit 1 }

$distRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "dist"
$outDir = Join-Path $distRoot "disk-alan-gorsellestirici"
$workDir = Join-Path $PSScriptRoot "build"
$stageDir = Join-Path $workDir "pyi-dist"
foreach ($d in @($outDir, $stageDir)) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }

Write-Host ">>> PyInstaller calistiriliyor (birkac dakika surebilir)..." -ForegroundColor Cyan
Invoke-Native $py @(
    "-m", "PyInstaller", "--noconfirm", "--clean",
    "--distpath", $stageDir, "--workpath", $workDir,
    (Join-Path $PSScriptRoot "DiskAlanGorsellestirici.spec")
)
if ($LASTEXITCODE -ne 0) { Write-Host "HATA: PyInstaller basarisiz." -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
Move-Item (Join-Path $stageDir "DiskAlanGorsellestirici") $outDir

$exe = Join-Path $outDir "DiskAlanGorsellestirici.exe"
if (-not (Test-Path $exe)) { Write-Host "HATA: $exe olusmadi." -ForegroundColor Red; exit 1 }
$sizeMb = [math]::Round(((Get-ChildItem $outDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host ""
Write-Host "Tamamlandi: $exe" -ForegroundColor Green
Write-Host "  Klasor boyutu: $sizeMb MB (tum klasoru birlikte tasiyin; kurulum: .\install.ps1)" -ForegroundColor DarkGray
