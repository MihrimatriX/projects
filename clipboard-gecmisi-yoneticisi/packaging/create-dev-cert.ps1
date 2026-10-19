$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$certName = "ClipboardGecmisiYoneticisi Dev"
$certDir = Join-Path $PSScriptRoot "certs"
$pfxPath = Join-Path $certDir "dev-signing.pfx"
$pfxPassword = "clipboard-dev"

if (-not (Test-Path $certDir)) {
    New-Item -ItemType Directory -Force -Path $certDir | Out-Null
}

$existing = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -match "CN=AFU" -and $_.FriendlyName -eq $certName } |
    Select-Object -First 1

if ($existing) {
    Write-Host ">>> Mevcut gelistirici sertifikasi kullaniliyor." -ForegroundColor Yellow
    $cert = $existing
}
else {
    Write-Host ">>> Self-signed gelistirici sertifikasi olusturuluyor..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate `
        -Type Custom `
        -Subject "CN=AFU" `
        -FriendlyName $certName `
        -KeyUsage DigitalSignature `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(5)
}

if (-not (Test-Path $pfxPath)) {
    $secure = ConvertTo-SecureString -String $pfxPassword -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secure | Out-Null
    Write-Host "    PFX: $pfxPath (sifre: $pfxPassword)" -ForegroundColor Green
}

Write-Host "`n>>> Guvenilir kok olarak yukleniyor (CurrentUser)..." -ForegroundColor Cyan
$root = $cert | Select-Object -ExpandProperty Thumbprint
$inStore = Get-ChildItem Cert:\CurrentUser\Root | Where-Object Thumbprint -eq $root
if (-not $inStore) {
    Export-Certificate -Cert $cert -FilePath (Join-Path $certDir "dev-signing.cer") | Out-Null
    Import-Certificate -FilePath (Join-Path $certDir "dev-signing.cer") -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
}

Write-Host "`n>>> Hazir. package-msix.ps1 -Sign ile imzalayabilirsiniz." -ForegroundColor Green
Write-Host "    Thumbprint: $($cert.Thumbprint)"
