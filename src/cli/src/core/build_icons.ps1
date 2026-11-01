Add-Type -AssemblyName System.Drawing

function New-TransparentVBitmap([int]$canvasSize) {
    $bmp = New-Object System.Drawing.Bitmap $canvasSize, $canvasSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # Scale and center V monogram nicely
    $scale = ($canvasSize * 0.90) / 285.0
    $dx = ($canvasSize / 2.0) - (270.5 * $scale)
    $dy = ($canvasSize / 2.0) - (240.5 * $scale)

    # 1. Left Wing (Cream / Warm Architectural White #f4ece1)
    $ptsLeft = @(
        (New-Object System.Drawing.PointF ((135 * $scale) + $dx), ((145 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((185 * $scale) + $dx), ((145 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((315 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((380 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((222 * $scale) + $dx), ((380 * $scale) + $dy))
    )
    $brushLeft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 244, 236, 225))
    $g.FillPolygon($brushLeft, $ptsLeft)
    $brushLeft.Dispose()

    # 2. Right Wing Main Body (LinearGradient: #ff5e1e to #ffa173)
    $ptR1 = New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((380 * $scale) + $dy)
    $ptR2 = New-Object System.Drawing.PointF ((377 * $scale) + $dx), ((145 * $scale) + $dy)
    $gradRight = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($ptR1, $ptR2, [System.Drawing.Color]::FromArgb(255, 255, 94, 30), [System.Drawing.Color]::FromArgb(255, 255, 161, 115))
    $ptsRight = @(
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((380 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((310 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((332 * $scale) + $dx), ((145 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((377 * $scale) + $dx), ((145 * $scale) + $dy))
    )
    $g.FillPolygon($gradRight, $ptsRight)
    $gradRight.Dispose()

    # 3. Right Wing Bevel Facet (LinearGradient: #ff7a3d to #ffcbb0)
    $ptB1 = New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((380 * $scale) + $dy)
    $ptB2 = New-Object System.Drawing.PointF ((377 * $scale) + $dx), ((145 * $scale) + $dy)
    $gradBevel = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($ptB1, $ptB2, [System.Drawing.Color]::FromArgb(255, 255, 122, 61), [System.Drawing.Color]::FromArgb(255, 255, 203, 176))
    $ptsBevel = @(
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((380 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((256 * $scale) + $dx), ((345 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((355 * $scale) + $dx), ((145 * $scale) + $dy)),
        (New-Object System.Drawing.PointF ((377 * $scale) + $dx), ((145 * $scale) + $dy))
    )
    $g.FillPolygon($gradBevel, $ptsBevel)
    $gradBevel.Dispose()

    # 4. Multimodal Spark (Orbital Node at 382, 125)
    $cX = (382 * $scale) + $dx
    $cY = (125 * $scale) + $dy

    # Aura glow
    $auraR = 24.0 * $scale
    $auraBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(85, 255, 122, 61))
    $g.FillEllipse($auraBrush, ($cX - $auraR), ($cY - $auraR), ($auraR * 2), ($auraR * 2))
    $auraBrush.Dispose()

    # Outer ring
    $ringR = 14.0 * $scale
    $ringBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 245, 238))
    $g.FillEllipse($ringBrush, ($cX - $ringR), ($cY - $ringR), ($ringR * 2), ($ringR * 2))
    $ringBrush.Dispose()

    # Core
    $coreR = 9.0 * $scale
    $coreBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 122, 61))
    $g.FillEllipse($coreBrush, ($cX - $coreR), ($cY - $coreR), ($coreR * 2), ($coreR * 2))
    $coreBrush.Dispose()

    $g.Dispose()
    return $bmp
}

# Multi-resolution sizes
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngBytesList = @()

foreach ($sz in $sizes) {
    $b = New-TransparentVBitmap $sz
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytesList += ,$ms.ToArray()
    $ms.Dispose()
    $b.Dispose()
}

# Save master PNG (256x256)
$masterPng = New-TransparentVBitmap 256
$masterPngMs = New-Object System.IO.MemoryStream
$masterPng.Save($masterPngMs, [System.Drawing.Imaging.ImageFormat]::Png)
$masterPngBytes = $masterPngMs.ToArray()
$masterPngMs.Dispose()
$masterPng.Dispose()

# Write modern PNG-in-ICO file
function Write-PngIco([byte[][]]$chunks, [int[]]$szs, [string]$outPath) {
    $fs = [System.IO.File]::Create($outPath)
    $bw = New-Object System.IO.BinaryWriter $fs

    $count = $chunks.Length
    $bw.Write([int16]0) # Reserved
    $bw.Write([int16]1) # Type 1 = ICO
    $bw.Write([int16]$count)

    $offset = 6 + (16 * $count)
    for ($i = 0; $i -lt $count; $i++) {
        $sz = $szs[$i]
        $w = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }
        $h = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }
        $bw.Write($w)
        $bw.Write($h)
        $bw.Write([byte]0)   # Color count
        $bw.Write([byte]0)   # Reserved
        $bw.Write([int16]1)  # Color planes
        $bw.Write([int16]32) # Bits per pixel
        $bw.Write([int32]$chunks[$i].Length)
        $bw.Write([int32]$offset)
        $offset += $chunks[$i].Length
    }

    for ($i = 0; $i -lt $count; $i++) {
        $bw.Write($chunks[$i])
    }

    $bw.Flush()
    $bw.Dispose()
    $fs.Dispose()
}

$tempIco = Join-Path $PSScriptRoot "temp_vork.ico"
Write-PngIco $pngBytesList $sizes $tempIco

$icoBytes = [System.IO.File]::ReadAllBytes($tempIco)
Remove-Item $tempIco -Force -ErrorAction SilentlyContinue

# Target destination directories
$destinations = @(
    (Join-Path $HOME ".vork"),
    (Join-Path $PSScriptRoot "..\..\public\img"),
    (Join-Path $PSScriptRoot "..")
)

foreach ($dest in $destinations) {
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    
    # Write vork.png / logo.png
    [System.IO.File]::WriteAllBytes((Join-Path $dest "vork.png"), $masterPngBytes)
    [System.IO.File]::WriteAllBytes((Join-Path $dest "vork.ico"), $icoBytes)
    
    if ($dest -like "*img*") {
        [System.IO.File]::WriteAllBytes((Join-Path $dest "logo.png"), $masterPngBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $dest "logo.ico"), $icoBytes)
    }
    Write-Host "Updated icons in: $dest"
}

Write-Host "Transparent V icons successfully created and deployed!" -ForegroundColor Green
