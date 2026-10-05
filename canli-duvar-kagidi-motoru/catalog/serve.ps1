$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
Write-Host "Katalog sunucusu: http://localhost:8080/index.json"
Write-Host "Durdurmak icin Ctrl+C"
python -m http.server 8080 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Python bulunamadi, npx serve deneniyor..."
    npx --yes serve -l 8080 .
}
