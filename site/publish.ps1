# Siteyi derler ve gh-pages dalına tek commit olarak yayınlar (Actions gerekmez).
# Kullanım: .\site\publish.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$remote = git -C $root remote get-url origin

node (Join-Path $PSScriptRoot "build.mjs")
if ($LASTEXITCODE -ne 0) { throw "Derleme başarısız." }

$site = Join-Path $root "_site"
git -C $site init -q -b gh-pages
git -C $site add -A
git -C $site -c user.name="$(git -C $root config user.name)" -c user.email="$(git -C $root config user.email)" commit -q -m "Site"
git -C $site push -q --force $remote gh-pages
if ($LASTEXITCODE -ne 0) { throw "Push başarısız." }
Write-Host "Yayınlandı: gh-pages (birkaç dakika içinde siteye yansır)"
