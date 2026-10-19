#Requires -Version 5.1
Set-Location $PSScriptRoot
$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "Once .\run.ps1 calistirin (venv yok)." -ForegroundColor Red
    exit 1
}
& $python -c "from utils.process_guard import kill_stale_instances; kill_stale_instances()"
Write-Host "Tum Tekrarlanan Dosya Bulucu surecleri kapatildi." -ForegroundColor Green
