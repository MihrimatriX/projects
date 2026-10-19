# Markdown Not Defteri marka varlıkları — launcher ve platform ikonları.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot | Split-Path -Parent
$brandDir = Join-Path $root "assets"
$winIcon = Join-Path $root "windows\runner\resources\app_icon.ico"
$webDir = Join-Path $root "web"

New-Item -ItemType Directory -Force -Path $brandDir | Out-Null

Add-Type -AssemblyName System.Drawing

function New-MdIconBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(255, 250, 249, 247))

    $accent = [System.Drawing.Color]::FromArgb(255, 9, 105, 218)
    $paper = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
    $line = [System.Drawing.Color]::FromArgb(255, 232, 230, 227)
    $text = [System.Drawing.Color]::FromArgb(140, 69, 69, 69)

    $pad = [int]($size * 0.12)
    $docW = $size - 2 * $pad
    $docH = [int]($size * 0.72)
    $docX = $pad
    $docY = [int]($size * 0.1)
    $radius = [int]($size * 0.06)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($docX, $docY, $radius * 2, $radius * 2, 180, 90)
    $path.AddArc($docX + $docW - $radius * 2, $docY, $radius * 2, $radius * 2, 270, 90)
    $path.AddArc($docX + $docW - $radius * 2, $docY + $docH - $radius * 2, $radius * 2, $radius * 2, 0, 90)
    $path.AddArc($docX, $docY + $docH - $radius * 2, $radius * 2, $radius * 2, 90, 90)
    $path.CloseFigure()
    $g.FillPath([System.Drawing.SolidBrush]::new($paper), $path)
    $g.DrawPath([System.Drawing.Pen]::new($line, [single]($size * 0.025)), $path)

    $barH = [int]($size * 0.045)
    $g.FillRectangle([System.Drawing.SolidBrush]::new($accent), $docX + [int]($size * 0.08), $docY + [int]($size * 0.14), [int]($size * 0.28), $barH)
    for ($i = 0; $i -lt 3; $i++) {
        $y = $docY + [int]($size * 0.24) + $i * [int]($size * 0.08)
        $w = [int]($size * (0.38 - $i * 0.04))
        $g.FillRectangle([System.Drawing.SolidBrush]::new($text), $docX + [int]($size * 0.08), $y, $w, [int]($size * 0.028))
    }

    $fontSize = [System.Single]($size * 0.22)
    $fontFamily = [System.Drawing.FontFamily]::new("Georgia")
    $font = [System.Drawing.Font]::new($fontFamily, $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString("#", $font, [System.Drawing.SolidBrush]::new($accent), $docX + [int]($size * 0.52), $docY + [int]($size * 0.48))

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

$master = New-MdIconBitmap 256
Save-Png $master (Join-Path $brandDir "icon.png")
Save-Png $master (Join-Path $brandDir "icon-256.png")
Save-Ico $master (Join-Path $brandDir "app.ico")
Save-Ico $master $winIcon

foreach ($s in @(192, 512)) {
    $bmp = New-MdIconBitmap $s
    Save-Png $bmp (Join-Path $webDir "icons\Icon-$s.png")
    Save-Png $bmp (Join-Path $webDir "icons\Icon-maskable-$s.png")
    $bmp.Dispose()
}

$fav = New-MdIconBitmap 48
Save-Png $fav (Join-Path $webDir "favicon.png")
$fav.Dispose()
$master.Dispose()

Write-Host "Varliklar uretildi: $brandDir" -ForegroundColor Green
