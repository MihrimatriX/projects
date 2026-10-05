$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Dosya Yeniden Adlandirici"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\DosyaYenidenAdlandirici"
$exeName = "DosyaYenidenAdlandirici.exe"

# publish.ps1 PyInstaller onedir cikti uretir: <repo>\dist\dosya-yeniden-adlandirici\ (exe + _internal)
$distDir = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\dosya-yeniden-adlandirici"
if (-not (Test-Path (Join-Path $distDir $exeName))) {
    Write-Host ">>> publish.ps1 calistiriliyor..." -ForegroundColor Yellow
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\publish.ps1"
    if ($LASTEXITCODE -ne 0) { throw "publish.ps1 basarisiz (cikis kodu $LASTEXITCODE)" }
}

Write-Host ">>> Kurulum: $installDir" -ForegroundColor Cyan
if (Get-Process -Name "DosyaYenidenAdlandirici" -ErrorAction SilentlyContinue) {
    throw "Uygulama calisiyor; once kapatin ve tekrar deneyin."
}
# Eski surum (onefile exe ya da eski _internal) yeni dosyalarla karismasin.
if (Test-Path $installDir) { Remove-Item -Recurse -Force $installDir }
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $distDir "*") $installDir -Recurse -Force

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")

foreach ($path in @(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
)) {
    $sc = $wsh.CreateShortcut($path)
    $sc.TargetPath = Join-Path $installDir $exeName
    $sc.WorkingDirectory = $installDir
    $sc.Description = $appName
    $sc.Save()
}

Write-Host "`n>>> Kurulum tamamlandi: $installDir" -ForegroundColor Green
