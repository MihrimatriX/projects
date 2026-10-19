$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$iconDir = Join-Path $root "assets\icon"
$src = Join-Path $iconDir "app_icon_512.png"

if (-not (Test-Path $src)) {
  Write-Error "Kaynak ikon bulunamadi: $src"
}

Add-Type -AssemblyName System.Drawing

function Save-Png($size, $dest) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $img = [System.Drawing.Image]::FromFile($src)
  $g.DrawImage($img, 0, 0, $size, $size)
  $g.Dispose()
  $img.Dispose()
  $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# Launcher asset boyutlari
Save-Png 192 (Join-Path $iconDir "app_icon_192.png")

# Web
$webIcons = Join-Path $root "web\icons"
foreach ($pair in @(@(192, "Icon-192.png"), @(512, "Icon-512.png"), @(192, "Icon-maskable-192.png"), @(512, "Icon-maskable-512.png"))) {
  Save-Png $pair[0] (Join-Path $webIcons $pair[1])
}

# Android mipmap
$densities = @{
  "mipmap-mdpi"    = 48
  "mipmap-hdpi"    = 72
  "mipmap-xhdpi"   = 96
  "mipmap-xxhdpi"  = 144
  "mipmap-xxxhdpi" = 192
}
$res = Join-Path $root "android\app\src\main\res"
foreach ($entry in $densities.GetEnumerator()) {
  Save-Png $entry.Value (Join-Path $res "$($entry.Key)\ic_launcher.png")
}

# Windows ICO (256px)
$icoPath = Join-Path $root "windows\runner\resources\app_icon.ico"
$bmp256 = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($bmp256)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$srcImg = [System.Drawing.Image]::FromFile($src)
$g.DrawImage($srcImg, 0, 0, 256, 256)
$g.Dispose()
$srcImg.Dispose()
$icon = [System.Drawing.Icon]::FromHandle($bmp256.GetHicon())
$fs = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
$icon.Save($fs)
$fs.Close()
$icon.Dispose()
$bmp256.Dispose()

Write-Host "Ikonlar senkronize edildi." -ForegroundColor Green
