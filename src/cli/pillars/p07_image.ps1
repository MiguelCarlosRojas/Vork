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
        Write-VorkSectionHeader -Title "Nueva conversión" -Subtitle "Ruta local o URL  ·  jpg · png · webp · ico · avif" -RightText "vork · imagen"
        $rawTarget = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $rawTarget -or -not $rawTarget.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
            Write-Host ""
            return
        }
    }

    # Limpieza estricta de comillas iniciales y finales y espacios
    $target = $rawTarget.Trim().Trim('"').Trim("'").Trim()
    $isUrl = ($target -match '^https?://')

    Write-VorkSectionHeader -Title "Imagen de origen" -RightText "vork · imagen"
    Write-VorkInfoRow -Label "Origen" -Value $target

    $imageBytes = $null
    $detectedFmt = "unknown"
    $detectedLabel = "Desconocido"

    if ($isUrl) {
        try {
            Write-VorkStatusLine -Kind step -Text "Conectando con el origen"
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
                    Write-VorkStatusLine -Kind info -Text "Imagen detectada en metadatos" -Detail $realImgUrl
                    $respBytes = $client.GetByteArrayAsync($realImgUrl).Result
                    $target = $realImgUrl
                } else {
                    Write-VorkStatusLine -Kind warn -Text "La URL es una página web sin imagen detectable (og:image)."
                    Write-Host ""
                    return
                }
            }

            $imageBytes = $respBytes
        } catch {
            Write-VorkStatusLine -Kind error -Text "Error al descargar la imagen" -Detail $_.Exception.Message
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
            Write-VorkStatusLine -Kind error -Text "Archivo no encontrado o ruta cancelada."
            Write-Host ""
            return
        }

        $target = $resolvedPath
        try {
            $imageBytes = [System.IO.File]::ReadAllBytes($target)
        } catch {
            Write-VorkStatusLine -Kind error -Text "No se pudo leer el archivo" -Detail $_.Exception.Message
            Write-Host ""
            return
        }
    }

    # Detección precisa de formato mediante Magic Bytes
    if ($imageBytes -and $imageBytes.Length -ge 4) {
        if ($imageBytes[0] -eq 0xFF -and $imageBytes[1] -eq 0xD8 -and $imageBytes[2] -eq 0xFF) {
            $detectedFmt = "jpg"; $detectedLabel = "JPEG · Joint Photographic Experts Group"
        } elseif ($imageBytes[0] -eq 0x89 -and $imageBytes[1] -eq 0x50 -and $imageBytes[2] -eq 0x4E -and $imageBytes[3] -eq 0x47) {
            $detectedFmt = "png"; $detectedLabel = "PNG · Portable Network Graphics con transparencia"
        } elseif ($imageBytes[0] -eq 0x47 -and $imageBytes[1] -eq 0x49 -and $imageBytes[2] -eq 0x46 -and $imageBytes[3] -eq 0x38) {
            $detectedFmt = "gif"; $detectedLabel = "GIF · Graphics Interchange Format"
        } elseif ($imageBytes[0] -eq 0x42 -and $imageBytes[1] -eq 0x4D) {
            $detectedFmt = "bmp"; $detectedLabel = "BMP · Windows Bitmap Image"
        } elseif ($imageBytes[0] -eq 0x00 -and $imageBytes[1] -eq 0x00 -and $imageBytes[2] -eq 0x01 -and $imageBytes[3] -eq 0x00) {
            $detectedFmt = "ico"; $detectedLabel = "ICO · Windows Icon / Favicon"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[0..3]) -eq "RIFF") -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[8..11]) -eq "WEBP")) {
            $detectedFmt = "webp"; $detectedLabel = "WEBP · Google WebP Modern Compressed Image"
        } elseif ($imageBytes.Length -ge 12 -and ([System.Text.Encoding]::ASCII.GetString($imageBytes[4..11]) -match 'ftypavif|ftypavis')) {
            $detectedFmt = "avif"; $detectedLabel = "AVIF · AV1 Image File Format Ultra-HD"
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

    Write-Host ""
    Write-VorkInfoRow -Label "Formato" -Value $detectedLabel -ValueColor $Green
    Write-VorkSectionRule

    # Catálogo de formatos de salida soportados
    $allFormats = @(
        @{ Value = "webp"; Name = "WEBP"; Desc = "Máxima compresión, fidelidad visual" },
        @{ Value = "png";  Name = "PNG";  Desc = "Sin pérdida, admite transparencia" },
        @{ Value = "jpg";  Name = "JPG";  Desc = "Fotografía con compresión optimizada" },
        @{ Value = "ico";  Name = "ICO";  Desc = "Favicon multirresolución de Windows" },
        @{ Value = "avif"; Name = "AVIF"; Desc = "Ultra HD de nueva generación" }
    )

    # El formato actual detectado NO debe aparecer como opción de selección
    $availableFormats = @($allFormats | Where-Object { $_.Value -ne $detectedFmt })

    if (-not $fmt -or $fmt -eq $detectedFmt) {
        $imgOptions = @()
        foreach ($formatItem in $availableFormats) {
            $imgOptions += @{
                Value = $formatItem.Value
                Label = $formatItem.Name
                Description = $formatItem.Desc
            }
        }

        $chosenFmt = Select-InteractiveOption -PromptTitle "Formato de salida" -Subtitle "imagen de destino" -Options $imgOptions -DefaultIndex 0
        if (-not $chosenFmt) {
            Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
            Write-Host ""
            return
        }
        $fmt = $chosenFmt
    }

    Write-VorkSectionHeader -Title "Procesando imagen" -RightText "vork · imagen"
    Write-VorkInfoRow -Label "Destino" -Value $fmt.ToUpper() -ValueColor $Yellow
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind step -Text "Convirtiendo $($detectedFmt.ToUpper()) a $($fmt.ToUpper())" -Detail "calidad $quality"

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

        Write-VorkStatusLine -Kind ok -Text "Conversión completada" -Detail "$($detectedFmt.ToUpper()) a $($fmt.ToUpper())"

        $localImg = if ($target -and (Test-Path $target)) {
            [System.IO.Path]::GetFileNameWithoutExtension($target) + "_convertido.$fmt"
        } else {
            "imagen_convertida.$fmt"
        }

        $outputMode = Select-VorkImageOutputAction -PromptTitle "Entrega de la imagen"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Generación cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "all")
        $hasDownload = $outputMode -in @("download", "all")

        if ($hasLocal) {
            try {
                Invoke-WebRequest -Uri $dlUrl -OutFile $localImg -UseBasicParsing -TimeoutSec 60
                $resolvedOut = (Resolve-Path $localImg).Path
                Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
            } catch {
                Write-VorkInfoRow -Label "Descarga" -Value $dlUrl -ValueColor $Yellow
            }
        }

        if ($hasDownload) {
            Write-VorkInfoRow -Label "Enlace" -Value $dlUrl -ValueColor $Cyan
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Conversor de Imagen" -Message "Conversión a $fmt completada con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de conversión" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
