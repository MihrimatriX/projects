$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host ">>> QR ve Barkod - Release build" -ForegroundColor Cyan
flutter pub get
flutter analyze
flutter test

if ($args -contains '-android') {
  flutter build apk --release
} elseif ($args -contains '-windows') {
  flutter build windows --release
} else {
  Write-Host "Kullanim: .\build.ps1 [-windows|-android]" -ForegroundColor Yellow
}
