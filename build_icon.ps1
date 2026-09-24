<#
.SYNOPSIS
    Convert PNG to Multi-Resolution Windows ICO
.DESCRIPTION
    Generates a high-quality Windows ICO containing 256, 128, 64, 48, 32, and 16 px entries.
#>

param(
    [string]$PngPath = (Join-Path $PSScriptRoot "icon.png"),
    [string]$IcoPath = (Join-Path $PSScriptRoot "assets\app.ico"),
    [switch]$Force
)

# The normalized owner asset is canonical. Do not let a routine icon build
# replace it with the older root PNG-derived artwork.
if (!$Force -and (Test-Path -LiteralPath $IcoPath)) {
    Write-Host "Canonical icon already exists; leaving it untouched: $IcoPath" -ForegroundColor Green
    exit 0
}

Add-Type -AssemblyName System.Drawing

if (!(Test-Path -LiteralPath $PngPath)) {
    Write-Error "PNG file not found: $PngPath"
    exit 1
}

$icoDirectory = Split-Path -Path $IcoPath -Parent
if (!(Test-Path -LiteralPath $icoDirectory)) {
    New-Item -ItemType Directory -Force -Path $icoDirectory | Out-Null
}

$srcImg = [System.Drawing.Bitmap]::FromFile($PngPath)
$Sizes = @(256, 128, 64, 48, 32, 16)
$pngStreams = [System.Collections.Generic.List[byte[]]]::new()

foreach ($size in $Sizes) {
    $bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()

    $ms = [System.IO.MemoryStream]::new()
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $pngStreams.Add($ms.ToArray())
    $ms.Dispose()
}
$srcImg.Dispose()

$fs = [System.IO.FileStream]::new($IcoPath, [System.IO.FileMode]::Create)
$bw = [System.IO.BinaryWriter]::new($fs)

# ICONDIR header (6 bytes)
$bw.Write([uint16]0)                 # Reserved (must be 0)
$bw.Write([uint16]1)                 # Type: 1 for icon
$bw.Write([uint16]$Sizes.Count)      # Count of images

$offset = 6 + (16 * $Sizes.Count)

# ICONDIRENTRY (16 bytes per entry)
for ($i = 0; $i -lt $Sizes.Count; $i++) {
    $size = $Sizes[$i]
    $wByte = if ($size -ge 256) { [byte]0 } else { [byte]$size }
    $hByte = if ($size -ge 256) { [byte]0 } else { [byte]$size }
    $data = $pngStreams[$i]

    $bw.Write($wByte)                # Width
    $bw.Write($hByte)                # Height
    $bw.Write([byte]0)               # Color count (0 = >= 8bpp)
    $bw.Write([byte]0)               # Reserved
    $bw.Write([uint16]1)             # Color Planes
    $bw.Write([uint16]32)            # Bits per pixel
    $bw.Write([uint32]$data.Length)  # Image byte size
    $bw.Write([uint32]$offset)       # Image data file offset
    $offset += $data.Length
}

# Image data blocks
for ($i = 0; $i -lt $Sizes.Count; $i++) {
    $bw.Write($pngStreams[$i])
}

$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "✅ Successfully generated multi-resolution icon: $IcoPath" -ForegroundColor Green
