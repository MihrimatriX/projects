# JSON Formatlayıcı — yerel kurulum (static build çıktısı veya Tauri release)
param(
  [switch]$Tauri
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

if ($Tauri) {
  Write-Host "Tauri release build..."
  Push-Location $root
  npm run tauri:build
  Pop-Location
  $msi = Get-ChildItem -Path (Join-Path $root "src-tauri\target\release\bundle") -Recurse -Include "*.msi","*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($msi) {
    Write-Host "Kurulum paketi: $($msi.FullName)"
    Start-Process $msi.FullName
  }
  exit 0
}

Write-Host "Static web build..."
Push-Location $root
npm run build:static
Pop-Location

$out = Join-Path $root "out"
if (-not (Test-Path $out)) {
  throw "out/ bulunamadi. build:static basarisiz olabilir."
}

$dest = Join-Path $env:LOCALAPPDATA "JSON-Formatlayici"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Copy-Item $out $dest -Recurse

$shortcutDir = [Environment]::GetFolderPath("Desktop")
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut((Join-Path $shortcutDir "JSON Formatlayici.lnk"))
$lnk.TargetPath = "powershell.exe"
$lnk.Arguments = "-NoProfile -Command `"Start-Process '$dest\index.html'`""
$lnk.WorkingDirectory = $dest
$lnk.Save()

Write-Host "Kopyalandi: $dest"
Write-Host "Masaustu kisayolu olusturuldu."
