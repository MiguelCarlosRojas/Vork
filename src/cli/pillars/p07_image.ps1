<#
.SYNOPSIS
    Pilar 07: Vork Conversor Universal de Formatos de Imagen (PNG, JPG, WEBP, ICO, AVIF)
#>

function Invoke-PillarImage {
    param([string[]]$ArgsList)

    $rawTarget = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $fmt = $null
    $quality = 90
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Format", "--format", "-f") { $fmt = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Quality", "--quality", "-q") { $quality = [int]$ArgsList[$i+1] }
        }
    }

    if (-not $rawTarget) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [07] Vork Conversor Universal de Imágenes${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta del archivo de imagen o URL (ej: logo.png o https://...):${Reset}"
        $rawTarget = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $rawTarget -or -not $rawTarget.Trim()) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
    }

    # Limpieza estricta de comillas iniciales y finales y espacios
    $target = $rawTarget.Trim().Trim('"').Trim("'").Trim()
    $isUrl = ($target -match '^https?://')

    $imageBytes = $null
    $detectedFmt = "unknown"
    $detectedLabel = "Desconocido"

    if ($isUrl) {
        try {
            Write-Host "  ${Lead}│${Reset} ${LeadLight}Conectando y analizando recurso web...${Reset}"
            try { Add-Type -AssemblyName System.Net.Http } catch { }
            $client = [System.Net.Http.HttpClient]::new()
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            $client.Timeout = [TimeSpan]::FromSeconds(25)
            $respBytes = $client.GetByteArrayAsync($target).Result

            # Verificar si la respuesta es HTML para extraer imagen de metadatos (og:image / twitter:image)
            $isHtml = $false
            if ($respBytes.Length -gt 15) {
                $headLen = [Math]::Min(1024, $respBytes.Length - 1)
                $headStr = [System.Text.Encoding]::UTF8.GetString($respBytes[0..$headLen])
                if ($headStr -match '<(!DOCTYPE\s+)?html|<head|<meta|<body') {
                    $isHtml = $true
                }
            }

            if ($isHtml) {
                $htmlText = [System.Text.Encoding]::UTF8.GetString($respBytes)
                $realImgUrl = $null
                if ($htmlText -match '<meta[^>]+property=["'']og:image["''][^>]+content=["'']([^"'']+)["'']' -or
                    $htmlText -match '<meta[^>]+content=["'']([^"'']+)["''][^>]+property=["'']og:image["'']' -or
                    $htmlText -match '<meta[^>]+name=["'']twitter:image["''][^>]+content=["'']([^"'']+)["'']' -or
                    $htmlText -match '<meta[^>]+content=["'']([^"'']+)["''][^>]+name=["'']twitter:image["'']') {
                    $realImgUrl = $Matches[1].Trim()
                }

                if ($realImgUrl) {
                    if ($realImgUrl.StartsWith("//")) { $realImgUrl = "https:" + $realImgUrl }
                    elseif ($realImgUrl.StartsWith("/")) {
                        $u = [System.Uri]$target
                        $realImgUrl = "$($u.Scheme)://$($u.Host)$realImgUrl"
                    }
                    Write-Host "  ${Lead}│${Reset} ${LeadLight}Imagen detectada en metadatos:${Reset} $realImgUrl"
                    $respBytes = $client.GetByteArrayAsync($realImgUrl).Result
                    $target = $realImgUrl
                } else {
                    Write-Host "  ${Lead}╰─ La URL es una página web sin metadatos de imagen (og:image) detectable.${Reset}"
                    Write-Host ""
                    return
                }
            }

            $imageBytes = $respBytes
        } catch {
            Write-Host "  ${Lead}╰─ Error al descargar imagen desde URL: $($_.Exception.Message)${Reset}"
            Write-Host ""
            return
        }
    } else {
        # Archivo local
        $resolvedPath = $null
        try {
            if (Test-Path -LiteralPath $target) {
                $resolvedPath = (Resolve-Path -LiteralPath $target).Path
            }
        } catch { }

        if (-not $resolvedPath -or -not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            Write-Host "  ${Lead}╰─ Archivo no encontrado o cancelado.${Reset}"
            Write-Host ""
            return
        }

        $target = $resolvedPath
        try {
            $imageBytes = [System.IO.File]::ReadAllBytes($target)
        } catch {
            Write-Host "  ${Lead}╰─ Error al leer el archivo: $($_.Exception.Message)${Reset}"
            Write-Host ""
            return
        }
    }

    # Detección precisa de formato mediante Magic Bytes
    if ($imageBytes -and $imageBytes.Length -ge 4) {
        if ($imageBytes[0] -eq 0xFF -and $imageBytes[1] -eq 0xD8 -and $imageBytes[2] -eq 0xFF) {
            $detectedFmt = "jpg"; $detectedLabel = "JPEG / JPG (Joint Photographic Experts Group)"
        } elseif ($imageBytes[0] -eq 0x89 -and $imageBytes[1] -eq 0x50 -and $imageBytes[2] -eq 0x4E -and $imageBytes[3] -eq 0x47) {
            $detectedFmt = "png"; $detectedLabel = "PNG (Portable Network Graphics - Con transparencia)"
        } elseif ($imageBytes[0] -eq 0x47 -and $imageBytes[1] -eq 0x49 -and $imageBytes[2] -eq 0x46 -and $imageBytes[3] -eq 0x38) {
            $detectedFmt = "gif"; $detectedLabel = "GIF (Graphics Interchange Format)"
        } elseif ($imageBytes[0] -eq 0x42 -and $imageBytes[1] -eq 0x4D) {
            $detectedFmt = "bmp"; $detectedLabel = "BMP (Windows Bitmap Image)"
        } elseif ($imageBytes[0] -eq 0x00 -and $imageBytes[1] -eq 0x00 -and $imageBytes[2] -eq 0x01 -and $imageBytes[3] -eq 0x00) {
            $detectedFmt = "ico"; $detectedLabel = "ICO (Windows Icon / Favicon)"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[0..3]) -eq "RIFF") -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[8..11]) -eq "WEBP")) {
            $detectedFmt = "webp"; $detectedLabel = "WEBP (Google WebP Modern Compressed Image)"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[4..11]) -match 'ftypavif|ftypavis')) {
            $detectedFmt = "avif"; $detectedLabel = "AVIF (AV1 Image File Format Ultra-HD)"
        }
    }

    # Fallback por extensión de archivo/URL si no se determinó por magic bytes
    if ($detectedFmt -eq "unknown") {
        $cleanTargetUrl = $target.Split('?')[0].Split('#')[0]
        $ext = [System.IO.Path]::GetExtension($cleanTargetUrl).TrimStart(".").ToLower()
        if ($ext -in "jpg", "jpeg") { $detectedFmt = "jpg"; $detectedLabel = "JPEG / JPG" }
        elseif ($ext -eq "png") { $detectedFmt = "png"; $detectedLabel = "PNG" }
        elseif ($ext -eq "webp") { $detectedFmt = "webp"; $detectedLabel = "WEBP" }
        elseif ($ext -eq "ico") { $detectedFmt = "ico"; $detectedLabel = "ICO" }
        elseif ($ext -eq "avif") { $detectedFmt = "avif"; $detectedLabel = "AVIF" }
        elseif ($ext -eq "gif") { $detectedFmt = "gif"; $detectedLabel = "GIF" }
        elseif ($ext -eq "bmp") { $detectedFmt = "bmp"; $detectedLabel = "BMP" }
    }

    Write-Host "  ${Lead}│${Reset}  ${Gray}Formato actual detectado:${Reset} ${Green}${Bold}$detectedLabel${Reset}"

    # Catálogo de formatos de salida soportados
    $allFormats = @(
        @{ Value = "webp"; Label = "webp (WebP Next-Gen - Máxima compresión y fidelidad visual)" },
        @{ Value = "png";  Label = "png  (PNG Lossless con canal alfa transparente)" },
        @{ Value = "jpg";  Label = "jpg  (JPEG estándar optimizado para fotografía)" },
        @{ Value = "ico";  Label = "ico  (Icono Windows Favicon multirresolución)" },
        @{ Value = "avif"; Label = "avif (AVIF Ultra-HD de nueva generación)" }
    )

    # El formato actual detectado NO debe aparecer como opción de selección
    $availableFormats = @($allFormats | Where-Object { $_.Value -ne $detectedFmt })

    if (-not $fmt -or $fmt -eq $detectedFmt) {
        $imgOptions = @()
        for ($idx = 0; $idx -lt $availableFormats.Count; $idx++) {
            $num = $idx + 1
            $imgOptions += @{
                Value = $availableFormats[$idx].Value
                Label = "[$num] $($availableFormats[$idx].Label)"
            }
        }

        $chosenFmt = Select-InteractiveOption -PromptTitle "Selecciona el formato de imagen destino:" -Options $imgOptions -DefaultIndex 0
        if ($chosenFmt) { $fmt = $chosenFmt } else { $fmt = $availableFormats[0].Value }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [07] VORK PROCESADOR DE IMÁGENES ────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset     $White$target$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Detectado:$Reset  $Green$detectedFmt$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Destino:$Reset    $Yellow$fmt$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $b64 = [System.Convert]::ToBase64String($imageBytes)
    $mimePrefix = switch ($detectedFmt) {
        "jpg"   { "image/jpeg" }
        "png"   { "image/png" }
        "webp"  { "image/webp" }
        "gif"   { "image/gif" }
        "bmp"   { "image/bmp" }
        "ico"   { "image/x-icon" }
        "avif"  { "image/avif" }
        default { "image/png" }
    }
    $body = @{ imageBase64 = "data:$mimePrefix;base64,$b64"; targetFormat = $fmt; quality = $quality } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/convert" -Method Post -Body $body -ContentType "application/json"
        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/image/download" }
        $stUrl = if ($res.streamUrl) { if ($res.streamUrl.StartsWith("http")) { $res.streamUrl } else { "$ApiBase$($res.streamUrl)" } } else { "$ApiBase/api/image/stream" }
        Write-Host "  $Cyan│$Reset  $Green✓ Conversión de imagen lista:$Reset"
        Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        Write-Host "  $Cyan│$Reset    Stream:   $Cyan$stUrl$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Imagen]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Wait-VorkGoBack
    Write-Host ""
}
