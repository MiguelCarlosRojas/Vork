<#
.SYNOPSIS
    Pilar 08: Vork Modificador de Imagen & Fondo IA con Prompt (BRIA RMBG + FLUX.1)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $userPrompt = $null
    $out = $null

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1]; continue }
            if ($ArgsList[$i] -in "-Prompt", "--prompt", "-p") { $userPrompt = $ArgsList[$i+1]; continue }
            if ($i -gt 0 -and -not $userPrompt -and -not $ArgsList[$i].StartsWith("-")) {
                $userPrompt = $ArgsList[$i]
            }
        }
    }

    if ($file) {
        $file = $file.Trim('"', "'", " ")
    }

    $isWebUrl = ($file -and $file -match '^https?://')
    $isLocalFile = ($file -and (Test-Path $file))

    if (-not $isWebUrl -and -not $isLocalFile) {
        Write-VorkSectionHeader -Title "Edición de imagen con IA" -Subtitle "Ruta local o URL de la imagen" -RightText "vork · imagen ia"
        $fileInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $fileInput -or -not $fileInput.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Edición cancelada."
            Write-Host ""
            return
        }
        $file = $fileInput.Trim('"', "'", " ")
        $isWebUrl = ($file -match '^https?://')
        $isLocalFile = (Test-Path $file)

        if (-not $isWebUrl -and -not $isLocalFile) {
            Write-VorkStatusLine -Kind error -Text "Archivo o URL no encontrado" -Detail $file
            Write-Host ""
            return
        }
    }

    if (-not $userPrompt) {
        Write-VorkSectionHeader -Title "Prompt de edición" -Subtitle "Ej: playa al atardecer, fondo blanco · enter para aislar el sujeto" -RightText "vork · imagen ia"
        $pInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if ($pInput -and $pInput.Trim()) {
            $userPrompt = $pInput.Trim()
        }
    }

    # Detección inteligente del modo según el prompt del usuario
    $cleanP = if ($userPrompt) { $userPrompt.ToLower().Trim() } else { "" }
    $mode = "prompt"
    $colorVal = "#FFFFFF"

    if (-not $cleanP -or $cleanP -in "sin fondo", "quitar fondo", "eliminar fondo", "transparente", "transparent", "corte", "silueta", "solo sujeto", "none") {
        $mode = "transparent"
        $userPrompt = "Aislamiento de silueta PNG transparente"
    } elseif ($cleanP -in "fondo blanco", "blanco", "white", "fondo blanco studio", "white background") {
        $mode = "color"
        $colorVal = "#FFFFFF"
        $userPrompt = "Fondo Blanco Studio (#FFFFFF)"
    } elseif ($cleanP -in "fondo negro", "negro", "black", "black background", "fondo negro cine") {
        $mode = "color"
        $colorVal = "#000000"
        $userPrompt = "Fondo Negro Cine (#000000)"
    }

    if (-not $out) {
        $ext = if ($mode -eq "transparent") { "png" } else { "jpg" }
        if ($isLocalFile) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $suffix = if ($mode -eq "prompt") { "_modificado" } else { "_nobg" }
            $out = "${baseName}${suffix}.$ext"
        } else {
            $out = if ($mode -eq "prompt") { "imagen_modificada.$ext" } else { "sin_fondo.$ext" }
        }
    }

    Write-VorkSectionHeader -Title "Procesando imagen" -RightText "vork · imagen ia"
    Write-VorkInfoRow -Label "Origen" -Value $file
    Write-VorkInfoRow -Label "Prompt" -Value $userPrompt -ValueColor $Cyan
    Write-VorkInfoRow -Label "Salida" -Value $out -ValueColor $Yellow
    Write-VorkSectionRule

    $bodyMap = @{ mode = $mode }
    if ($mode -eq "prompt") {
        $bodyMap["prompt"] = $userPrompt
    } elseif ($mode -eq "color") {
        $bodyMap["color"] = $colorVal
    }

    if ($isLocalFile) {
        $resolved = Resolve-Path $file
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $b64 = [System.Convert]::ToBase64String($bytes)
        $bodyMap["imageBase64"] = "data:image/jpeg;base64,$b64"
    } else {
        $bodyMap["url"] = $file
    }

    $body = $bodyMap | ConvertTo-Json

    try {
        if ($mode -eq "prompt") {
            Write-VorkStatusLine -Kind step -Text "Aislando el sujeto con BRIA RMBG 1.4"
            Write-VorkStatusLine -Kind step -Text "Generando la modificación con FLUX.1 Neural"
            Write-VorkStatusLine -Kind step -Text "Componiendo la imagen final en alta resolución"
        } else {
            Write-VorkStatusLine -Kind step -Text "Procesando la silueta con IA neuronal"
        }

        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/image/download?id=$($res.id)" }

        Write-VorkStatusLine -Kind ok -Text "Edición completada"

        $outputMode = Select-VorkImageOutputAction -PromptTitle "Entrega de la imagen"
        if (-not $outputMode) { $outputMode = "all" }

        $hasLocal = $outputMode -in @("local", "all")
        $hasDownload = $outputMode -in @("download", "all")

        if ($hasLocal) {
            try {
                Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 90
                $resolvedOut = (Resolve-Path $out).Path
                Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
            } catch {
                Write-VorkInfoRow -Label "Descarga" -Value $dlUrl -ValueColor $Yellow
            }
        }

        if ($hasDownload) {
            Write-VorkInfoRow -Label "Enlace" -Value $dlUrl -ValueColor $Cyan
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Fondo IA" -Message "Edición de imagen completada con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de procesamiento IA" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
