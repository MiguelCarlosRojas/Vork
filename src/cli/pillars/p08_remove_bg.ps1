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
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [08] Vork Modificador de Imagen & Fondo IA con Prompt${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la ruta o URL de la imagen (ej: producto.jpg o enlace web):${Reset}"
        $fileInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $fileInput -or -not $fileInput.Trim()) {
            Write-Host "  ${Lead}╰─ Imagen no válida o cancelado.${Reset}"
            Write-Host ""
            return
        }
        $file = $fileInput.Trim('"', "'", " ")
        $isWebUrl = ($file -match '^https?://')
        $isLocalFile = (Test-Path $file)

        if (-not $isWebUrl -and -not $isLocalFile) {
            Write-Host "  ${Lead}╰─ [!] Archivo o URL no encontrado: $file${Reset}"
            Write-Host ""
            return
        }
    }

    if (-not $userPrompt) {
        Write-Host "  ${Lead}│${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Describe qué deseas modificar en la imagen (prompt):${Reset}"
        Write-Host "  ${Lead}│${Reset} ${LeadLight}(Ej: playa paradisíaca al atardecer, oficina moderna, fondo blanco, o enter para sin fondo)${Reset}"
        $pInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
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

    Write-Host ""
    Write-Host "  $Cyan╭─ [08] VORK ESTUDIO Y MODIFICADOR DE IMAGEN IA ────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset   $White$file$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Prompt:$Reset   $Cyan`"$userPrompt`"$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

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
            Write-Host "  $Cyan│$Reset  ${LeadLight}Aislando sujeto con BRIA RMBG 1.4...${Reset}"
            Write-Host "  $Cyan│$Reset  ${LeadLight}Generando modificación con IA FLUX.1 Neural...${Reset}"
            Write-Host "  $Cyan│$Reset  ${LeadLight}Componiendo imagen final de alta resolución...${Reset}"
        } else {
            Write-Host "  $Cyan│$Reset  ${LeadLight}Procesando silueta con IA neuronal...${Reset}"
        }

        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/image/download?id=$($res.id)" }

        Write-Host "  $Cyan│$Reset  $Green✓ Modificación de imagen completada exitosamente.$Reset"
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 90
            $resolvedOut = (Resolve-Path $out).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } catch {
            Write-Host "  $Cyan│$Reset  $Yellow URL de descarga:$Reset $White$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Imagen IA]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
