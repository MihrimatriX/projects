$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$appName = "Dosya ve Klasor Karsilastirici"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\DosyaKarsilastirici"
$releaseDir = Join-Path $PSScriptRoot "release"

$exe = Get-ChildItem -Path $releaseDir -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $exe) {
    Write-Host ">>> Once publish.ps1 calistiriliyor..." -ForegroundColor Yellow
    & "$PSScriptRoot\publish.ps1"
    $exe = Get-ChildItem -Path $releaseDir -Filter "*.exe" -Recurse | Select-Object -First 1
}

if (-not $exe) {
    Write-Error "Portable exe bulunamadi."
}

Write-Host ">>> Kurulum: $installDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item $exe.FullName (Join-Path $installDir $exe.Name) -Force

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
$lnkName = "$appName.lnk"

foreach ($dir in @($desktop, $startMenu)) {
    $sc = $wsh.CreateShortcut((Join-Path $dir $lnkName))
    $sc.TargetPath = Join-Path $installDir $exe.Name
    $sc.WorkingDirectory = $installDir
    $sc.Description = $appName
    $sc.Save()
}

Write-Host "`n>>> Kurulum tamamlandi." -ForegroundColor Green
Write-Host "    $installDir\$($exe.Name)"
