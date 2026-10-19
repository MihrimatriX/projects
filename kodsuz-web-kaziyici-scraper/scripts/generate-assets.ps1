# Kodsuz Web Kazıyıcı marka varlıklarını üretir.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot | Split-Path -Parent
$assets = Join-Path $root "assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null

Add-Type -AssemblyName System.Drawing

function New-ScraperBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

    $bg = [System.Drawing.Color]::FromArgb(255, 17, 24, 39)
    $accent = [System.Drawing.Color]::FromArgb(255, 59, 130, 246)
    $face = [System.Drawing.Color]::FromArgb(255, 249, 250, 251)
    $ok = [System.Drawing.Color]::FromArgb(255, 16, 185, 129)

    $margin = [int]($size * 0.12)
    $g.FillRectangle(
        [System.Drawing.SolidBrush]::new($bg),
        0, 0, $size, $size
    )
    $inner = $margin
    $rect = New-Object System.Drawing.Rectangle $inner, $inner, ($size - 2 * $inner), ($size - 2 * $inner)
    $pen = New-Object System.Drawing.Pen $accent, ([single]($size * 0.05))
    $g.DrawRectangle($pen, $rect)

    $gridPen = New-Object System.Drawing.Pen $face, ([single]($size * 0.04))
    $gridPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $gridPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $third = $size / 3.0
    $g.DrawLine($gridPen, $inner, $third, ($size - $inner), $third)
    $g.DrawLine($gridPen, $inner, 2 * $third, ($size - $inner), 2 * $third)
    $g.DrawLine($gridPen, $third, $inner, $third, ($size - $inner))

    $dot = [int]($size * 0.08)
    $g.FillEllipse([System.Drawing.SolidBrush]::new($ok), $size - $margin - $dot, $size - $margin - $dot, $dot, $dot)

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

$sizes = @{
    "icon.png" = 256
    "icon-256.png" = 256
    "icon-128.png" = 128
    "icon-64.png" = 64
    "icon-48.png" = 48
    "icon-32.png" = 32
    "icon-16.png" = 16
}

foreach ($entry in $sizes.GetEnumerator()) {
    $bmp = New-ScraperBitmap $entry.Value
    Save-Png $bmp (Join-Path $assets $entry.Key)
    $bmp.Dispose()
}

$master = New-ScraperBitmap 256
Save-Ico $master (Join-Path $assets "app.ico")
$master.Dispose()

Write-Host "Varliklar uretildi: $assets" -ForegroundColor Green
