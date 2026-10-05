$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Clipboard Ge$([char]0x00E7)mi$([char]0x015F)i Y$([char]0x00F6)neticisi"  # ASCII betik (PS 5.1 BOM-suz UTF-8 okumaz)
$installDir = Join-Path $env:LOCALAPPDATA "Programs\ClipboardGecmisiYoneticisi"
$publishDir = Join-Path (Split-Path $PSScriptRoot -Parent) ("dist\" + (Split-Path $PSScriptRoot -Leaf))
$exeName = "ClipboardGecmisiYoneticisi.exe"

if (-not (Test-Path (Join-Path $publishDir $exeName))) {
    Write-Host ">>> Once publish.ps1 calistiriliyor..." -ForegroundColor Yellow
    & "$PSScriptRoot\publish.ps1"
}

Write-Host ">>> Kurulum: $installDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $publishDir "*") $installDir -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "releases/version.json") $installDir -Force

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
Write-Host "`n    Uygulamayi baslatmak icin:" -ForegroundColor Yellow
Write-Host "    Start-Process `"$(Join-Path $installDir $exeName)`""
