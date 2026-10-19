# Web icin Drift WASM dosyalarini hazirlar (sqlite3.wasm + drift_worker.js)
# ponytail: sqlite3.wasm surumu pubspec.lock ile ESLESMEZSE LinkError (dispatch_xFunc) olur.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$webDir = Join-Path $PSScriptRoot "web"
$lockFile = Join-Path $PSScriptRoot "pubspec.lock"
$stampFile = Join-Path $webDir ".wasm-setup-stamp"

function Get-LockVersion([string]$Package) {
    $lines = Get-Content $lockFile
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq "  ${Package}:") {
            for ($j = $i + 1; $j -lt [Math]::Min($i + 12, $lines.Count); $j++) {
                if ($lines[$j] -match '^    version: "([^"]+)"') { return $Matches[1] }
                if ($lines[$j] -match '^  \w') { break }
            }
        }
    }
    throw "$Package surumu pubspec.lock icinde bulunamadi."
}

function Get-ReleaseAsset([string]$Repo, [string]$Tag, [string]$AssetName) {
    $headers = @{ "User-Agent" = "MinimalPodcast-Setup" }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
    if (-not $asset) { throw "$Repo $Tag icinde '$AssetName' bulunamadi." }
    return $asset.browser_download_url
}

$driftVer = Get-LockVersion "drift"
$sqliteVer = Get-LockVersion "sqlite3"
$stamp = "drift=$driftVer;sqlite3=$sqliteVer"

$wasmPath = Join-Path $webDir "sqlite3.wasm"
$workerJs = Join-Path $webDir "drift_worker.js"
$workerDart = Join-Path $webDir "drift_worker.dart"

if ((Test-Path $stampFile) -and (Get-Content $stampFile -Raw).Trim() -eq $stamp -and (Test-Path $wasmPath) -and (Test-Path $workerJs)) {
    Write-Host "Web WASM guncel ($stamp)"
    exit 0
}

Write-Host "Web WASM hazirlaniyor ($stamp)..."

New-Item -ItemType Directory -Force -Path $webDir | Out-Null

$sqliteTag = "sqlite3-$sqliteVer"
$sqliteUrl = Get-ReleaseAsset "simolus3/sqlite3.dart" $sqliteTag "sqlite3.wasm"
Write-Host "sqlite3.wasm indiriliyor ($sqliteTag)..."
Invoke-WebRequest -Uri $sqliteUrl -OutFile $wasmPath -UseBasicParsing

Write-Host "drift_worker.js derleniyor (dart compile js)..."
if (-not (Test-Path $workerDart)) {
    @'
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
'@ | Set-Content -Path $workerDart -Encoding UTF8
}

dart compile js -O4 -o $workerJs $workerDart
if ($LASTEXITCODE -ne 0) { throw "drift_worker.js derlenemedi." }

Set-Content -Path $stampFile -Value $stamp -Encoding UTF8
Write-Host "Web WASM hazir: $wasmPath, $workerJs"
