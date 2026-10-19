# Ekran Zamanı marka varlıklarını üretir ve WinUI Assets klasörüne kopyalar.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$brandDir = Join-Path $root "assets"
$winUiAssets = Join-Path $root "windows\EkranZamani.WinUI\Assets"

New-Item -ItemType Directory -Force -Path $brandDir, $winUiAssets | Out-Null

Add-Type -AssemblyName System.Drawing

function New-ClockBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

    $accent = [System.Drawing.Color]::FromArgb(255, 0, 113, 227)
    $face = [System.Drawing.Color]::FromArgb(255, 245, 245, 247)

    $margin = [int]($size * 0.08)
    $g.FillEllipse([System.Drawing.SolidBrush]::new($accent), $margin, $margin, $size - 2 * $margin, $size - 2 * $margin)
    $inner = [int]($size * 0.18)
    $g.FillEllipse([System.Drawing.SolidBrush]::new($face), $inner, $inner, $size - 2 * $inner, $size - 2 * $inner)

    $cx = $size / 2.0
    $cy = $size / 2.0
    $pen = New-Object System.Drawing.Pen $accent, ([single]($size * 0.07))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($pen, $cx, $cy, $cx, $cy - ($size * 0.22))
    $g.DrawLine($pen, $cx, $cy, $cx + ($size * 0.16), $cy)

    $g.Dispose()
    return $bmp
}

function Save-Png($bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Save-Ico([System.Drawing.Bitmap]$source, [string]$path) {
    $icon = [System.Drawing.Icon]::FromHandle($source.GetHicon())
    $fs = [System.IO.File]::Create($path)
    $icon.Save($fs)
    $fs.Close()
    $icon.Dispose()
}

$master = New-ClockBitmap 256
Save-Png $master (Join-Path $brandDir "icon-256.png")
Save-Ico $master (Join-Path $brandDir "icon.ico")

$sizes = @{
    "Square150x150Logo.scale-200.png" = 300
    "Square44x44Logo.scale-200.png" = 88
    "Square44x44Logo.targetsize-24_altform-unplated.png" = 24
    "Square44x44Logo.targetsize-48_altform-lightunplated.png" = 48
    "StoreLogo.png" = 50
    "Wide310x150Logo.scale-200.png" = 620
    "SplashScreen.scale-200.png" = 620
    "LockScreenLogo.scale-200.png" = 48
    "AppIcon.ico" = 256
}

foreach ($entry in $sizes.GetEnumerator()) {
    $target = Join-Path $winUiAssets $entry.Key
    if ($entry.Key.EndsWith(".ico")) {
        Save-Ico (New-ClockBitmap $entry.Value) $target
        Copy-Item $target (Join-Path $brandDir "icon.ico") -Force
    }
    else {
        $bmp = New-ClockBitmap $entry.Value
        Save-Png $bmp $target
        if ($entry.Key -eq "Square150x150Logo.scale-200.png") {
            Save-Png $bmp (Join-Path $brandDir "icon-256.png")
        }
        $bmp.Dispose()
    }
}

$master.Dispose()

Write-Host "Varlıklar üretildi:" -ForegroundColor Green
Write-Host "  $brandDir"
Write-Host "  $winUiAssets"
