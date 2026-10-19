# Canli Duvar Kagidi Motoru — Release paketleme
# Cikti: dist/app/CanliDuvarKagidi.exe (+ catalog/)
#        dist/CanliDuvarKagidi-Setup-x64.exe (Inno Setup varsa)
#        dist/CanliDuvarKagidi-Portable-x64.zip

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host "==> Katalog paketleri olusturuluyor..."
& "$root\catalog\pack-catalog.ps1"

$appDir = Join-Path $root "dist\app"
if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

Write-Host "==> Release derleniyor (tek exe, self-contained)..."
dotnet publish "$root\src\CanliDuvarKagidi.Shell\CanliDuvarKagidi.Shell.csproj" `
    -c Release `
    -p:Platform=x64 `
    -p:PublishExe=true `
    -p:PublishProfile=win-x64-exe `
    -o $appDir  # *.pubxml gitignore'da; cikti dizini burada verilmeli

$exePath = Join-Path $appDir "CanliDuvarKagidi.exe"
if (-not (Test-Path $exePath)) {
    throw "Publish basarisiz: $exePath bulunamadi"
}

# Katalog dosyalarini exe yanina kopyala
$catalogDest = Join-Path $appDir "catalog"
New-Item -ItemType Directory -Force -Path (Join-Path $catalogDest "assets") | Out-Null
Copy-Item "$root\catalog\index.json" $catalogDest -Force
Copy-Item "$root\catalog\assets\*.zip" (Join-Path $catalogDest "assets") -Force

Copy-Item "$root\README.md" $appDir -Force
$sizeMb = [math]::Round((Get-Item $exePath).Length / 1MB, 1)
Write-Host "OK: $exePath ($sizeMb MB)"

# Portable zip
$zipPath = Join-Path $root "dist\CanliDuvarKagidi-Portable-x64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$appDir\*" -DestinationPath $zipPath -Force
Write-Host "OK: $zipPath"

# Inno Setup installer
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

if ($iscc) {
    Write-Host "==> Inno Setup ile kurulum exe olusturuluyor..."
    & $iscc "$root\installer\CanliDuvarKagidi.iss"
    $setupExe = Join-Path $root "dist\CanliDuvarKagidi-Setup-x64.exe"
    if (Test-Path $setupExe) {
        $setupMb = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
        Write-Host "OK: $setupExe ($setupMb MB)"
    }
} else {
    Write-Host ""
    Write-Host "Inno Setup bulunamadi. Tek kurulum exe icin:"
    Write-Host "  winget install JRSoftware.InnoSetup"
    Write-Host "  Sonra tekrar: .\build\publish.ps1"
    Write-Host ""
    Write-Host "Simdilik portable zip kullanin: $zipPath"
}

Write-Host ""
Write-Host "Tamamlandi."
