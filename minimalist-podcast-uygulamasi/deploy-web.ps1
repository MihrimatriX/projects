# Statik web derlemesi (GitHub Pages / nginx için)
Set-Location $PSScriptRoot
& "$PSScriptRoot\setup-web.ps1"
flutter pub get
dart run build_runner build
flutter build web
Write-Host "Çıktı: build/web"
