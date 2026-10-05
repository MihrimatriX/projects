$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Sistem Yöneticisi Paketi"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\SistemYoneticisiPaketi"
$publishDir = Join-Path (Split-Path $PSScriptRoot -Parent) ("dist\" + (Split-Path $PSScriptRoot -Leaf))
$exeName = "SistemYoneticisiPaketi.exe"

if (-not (Test-Path (Join-Path $publishDir $exeName))) {
    Write-Host ">>> Once publish.ps1 calistiriliyor..." -ForegroundColor Yellow
    & "$PSScriptRoot\publish.ps1"
}

Write-Host ">>> Kurulum: $installDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $publishDir "*") $installDir -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "releases/version.json") $installDir -Force -ErrorAction SilentlyContinue

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("StartMenu")

$shortcutPaths = @(
    (Join-Path $desktop "$appName.lnk"),
    (Join-Path $startMenu "Programs\$appName.lnk")
)

foreach ($path in $shortcutPaths) {
    $sc = $wsh.CreateShortcut($path)
    $sc.TargetPath = Join-Path $installDir $exeName
    $sc.WorkingDirectory = $installDir
    $sc.Description = $appName
    $sc.Save()
}

Write-Host "`n>>> Kurulum tamamlandi." -ForegroundColor Green
Write-Host "    Konum: $installDir"
Write-Host "    Masaustu ve Baslat menusu kisayollari olusturuldu."
