#Requires -Version 5.1
<#
.SYNOPSIS
  Otomasyon ve Makro Araci - dist ciktisini %LOCALAPPDATA%\Programs\OtomasyonMakro altina kurar,
  masaustu ve Baslat menusu kisayolu olusturur. Makrolar %LOCALAPPDATA%\OtomasyonMakro altinda kalir.
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$appName = 'Otomasyon ve Makro Araci'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\OtomasyonMakro'
$publishDir = Join-Path (Split-Path $PSScriptRoot -Parent) ('dist\' + (Split-Path $PSScriptRoot -Leaf))
$exeName = 'OtomasyonMakro.exe'

if (-not (Test-Path (Join-Path $publishDir $exeName))) {
    Write-Host '>>> Once publish.ps1 calistiriliyor...' -ForegroundColor Yellow
    & "$PSScriptRoot\publish.ps1"
}
if (Get-Process -Name 'OtomasyonMakro' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$installDir\*" }) {
    throw 'Kurulu Otomasyon ve Makro Araci calisiyor; once uygulamayi kapatin.'
}

Write-Host ">>> Kurulum: $installDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $publishDir '*') $installDir -Recurse -Force

$exePath = Join-Path $installDir $exeName
$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = [Environment]::GetFolderPath('StartMenu')

foreach ($path in @((Join-Path $desktop "$appName.lnk"), (Join-Path $startMenu "Programs\$appName.lnk"))) {
    $sc = $wsh.CreateShortcut($path)
    $sc.TargetPath = $exePath
    $sc.WorkingDirectory = $installDir
    $sc.Description = $appName
    $sc.IconLocation = "$exePath,0"
    $sc.Save()
}

Write-Host "`n>>> Kurulum tamamlandi." -ForegroundColor Green
Write-Host "    Konum: $installDir"
Write-Host '    Masaustu ve Baslat menusu kisayollari olusturuldu.'
