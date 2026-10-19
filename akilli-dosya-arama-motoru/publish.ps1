#Requires -Version 5.1
<#
.SYNOPSIS
  Akilli Dosya Arama - bagimsiz exe (PyInstaller --onedir --windowed).
  Cikti: <repo>\dist\akilli-dosya-arama-motoru\AkilliDosyaArama.exe
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">>> Akilli Dosya Arama - EXE derlemesi" -ForegroundColor Cyan

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $ErrorActionPreference = "Continue"
    & $Exe @Arguments
}

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    # run.ps1 -Check venv'i olusturur, bagimliliklari kurar ve testleri calistirir.
    Invoke-Native "powershell.exe" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "run.ps1"), "-Check")
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $py)) {
        Write-Host "HATA: Sanal ortam hazirlanamadi veya testler basarisiz." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Derleme bagimliliklari yukleniyor..." -ForegroundColor DarkGray
Invoke-Native $py @("-m", "pip", "install", "--disable-pip-version-check", "-q", "-r", "requirements-build.txt")
if ($LASTEXITCODE -ne 0) { Write-Host "HATA: pip install basarisiz." -ForegroundColor Red; exit 1 }

# Exe ikonu: tepsi simgesinden uretilir (assets/app.ico gitignore'da).
$env:QT_QPA_PLATFORM = "offscreen"
Invoke-Native $py @("-c", "import os; os.makedirs('assets', exist_ok=True); from PySide6.QtGui import QGuiApplication; a = QGuiApplication([]); from utils.tray_icon import create_tray_header_icon; import sys; sys.exit(0 if create_tray_header_icon(256).save('assets/app.ico') else 1)")
Remove-Item Env:QT_QPA_PLATFORM
if ($LASTEXITCODE -ne 0) { Write-Host "UYARI: ikon uretilemedi, varsayilan ikon kullanilacak." -ForegroundColor Yellow }

$distRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "dist"
$outDir = Join-Path $distRoot "akilli-dosya-arama-motoru"
$workDir = Join-Path $PSScriptRoot "build"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }

Write-Host "PyInstaller calistiriliyor (birkac dakika surebilir)..." -ForegroundColor Yellow
Invoke-Native $py @("-m", "PyInstaller", "--noconfirm", "--clean", "--distpath", $distRoot, "--workpath", $workDir, "akilli-dosya-arama.spec")
if ($LASTEXITCODE -ne 0) { Write-Host "HATA: PyInstaller basarisiz." -ForegroundColor Red; exit 1 }

$exe = Join-Path $outDir "AkilliDosyaArama.exe"
if (-not (Test-Path $exe)) { Write-Host "HATA: $exe olusmadi." -ForegroundColor Red; exit 1 }

$sizeMb = [math]::Round(((Get-ChildItem $outDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host ""
Write-Host "Tamamlandi: $exe" -ForegroundColor Green
Write-Host "  Klasor boyutu: $sizeMb MB (tum klasoru birlikte tasiyin)" -ForegroundColor DarkGray
