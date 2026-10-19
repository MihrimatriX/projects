#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets = Join-Path $root "assets"
$out = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-PngSample {
    param([string]$Path)
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap 640, 360
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new(640, 360),
        [System.Drawing.Color]::FromArgb(255, 15, 32, 39),
        [System.Drawing.Color]::FromArgb(255, 44, 83, 100)
    )
    $g.FillRectangle($brush, 0, 0, 640, 360)
    $g.Dispose()
    $brush.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$pngPath = Join-Path $assets "ornek-gorsel\wallpaper.png"
New-PngSample -Path $pngPath

# Baslik/aciklama/tur her paketin manifest.json'indan okunur (Turkce metin betikte degil, UTF-8 JSON'da;
# boylece betik ASCII kalir). RequiresFile: paket yalnizca bu dosya varsa yayinlanir.
$packages = @(
    @{ Name = "ornek-web" },
    @{ Name = "ornek-gorsel" },
    @{ Name = "ornek-video"; RequiresFile = "wallpaper.mp4" }
)
foreach ($pkg in $packages) {
    $pkg.Path = Join-Path $assets $pkg.Name
    $m = Get-Content -Raw -Encoding UTF8 (Join-Path $pkg.Path "manifest.json") | ConvertFrom-Json
    $pkg.Entry = [ordered]@{
        id = $pkg.Name
        title = $m.title
        type = $m.type
        version = $m.version
        description = $m.description
        packageUrl = "assets/$($pkg.Name).zip"
    }
}

$indexEntries = @()

foreach ($pkg in $packages) {
    if ($pkg.RequiresFile) {
        $required = Join-Path $pkg.Path $pkg.RequiresFile
        if (-not (Test-Path $required)) {
            Write-Host "Atlaniyor $($pkg.Name) - $($pkg.RequiresFile) yok"
            continue
        }
    }

    $zip = Join-Path $out "$($pkg.Name).zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path (Join-Path $pkg.Path "*") -DestinationPath $zip -Force
    Copy-Item $zip (Join-Path $assets "$($pkg.Name).zip") -Force
    $indexEntries += $pkg.Entry
    Write-Host "Olusturuldu $($pkg.Name).zip"
}

# Eski/bos video zip kaldir
$staleVideoZip = Join-Path $assets "ornek-video.zip"
if (Test-Path $staleVideoZip) { Remove-Item $staleVideoZip -Force }

$index = @{
    version = "1.0.0"
    wallpapers = $indexEntries
}
$indexPath = Join-Path $root "index.json"
$index | ConvertTo-Json -Depth 5 | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "Guncellendi index.json"
