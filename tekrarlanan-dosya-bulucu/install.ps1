$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Tekrarlanan Dosya Bulucu"

function Get-PythonExe {
    $candidates = @(
        (Join-Path $PSScriptRoot ".venv\Scripts\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) { return @("py", "-3") }
    foreach ($name in @("python3", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notmatch "WindowsApps") { return $cmd.Source }
    }
    throw "Python 3.11+ bulunamadi."
}

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
    # Mevcut venv'in python.exe'si ile "-m venv .venv" çalışırken kendi exe'sini kopyalayamaz
    Write-Host ">>> Sanal ortam kuruluyor..." -ForegroundColor Cyan
    $py = Get-PythonExe
    if ($py -is [array]) {
        & $py[0] $py[1] -m venv .venv
    } else {
        & $py -m venv .venv
    }
}
$venvPy = ".\.venv\Scripts\python.exe"
& $venvPy -m pip install -r requirements.txt -q

$exeName = "TekrarlananDosyaBulucu.exe"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\TekrarlananDosyaBulucu"

$args = $null
# publish.ps1 ciktisi: <repo>\dist\tekrarlanan-dosya-bulucu\ (exe + _internal klasoru)
$distDir = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\tekrarlanan-dosya-bulucu"
if (Test-Path (Join-Path $distDir $exeName)) {
    Write-Host ">>> EXE kuruluyor: $installDir" -ForegroundColor Cyan
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    Copy-Item (Join-Path $distDir "*") $installDir -Recurse -Force
    $target = Join-Path $installDir $exeName
    $workDir = $installDir
} else {
    Write-Host ">>> Kaynak modu (dist yok) — run.ps1 kisayolu" -ForegroundColor Yellow
    $target = "powershell.exe"
    $launcher = Join-Path $PSScriptRoot "run.ps1"
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
    $workDir = $PSScriptRoot
}

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$lnk = Join-Path $desktop "$appName.lnk"
$sc = $wsh.CreateShortcut($lnk)
$sc.TargetPath = $target
if ($args) { $sc.Arguments = $args }
$sc.WorkingDirectory = $workDir
$sc.Description = $appName
$sc.Save()

Write-Host ">>> Kurulum tamamlandi." -ForegroundColor Green
