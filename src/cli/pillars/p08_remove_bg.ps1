<#
.SYNOPSIS
    Pilar 08: Vork Estudio y Eliminador / Modificador de Fondo IA (BRIA RMBG + FLUX.1)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $out = $null
    $mode = $null
    $userPrompt = $null

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Mode", "--mode", "-m") { $mode = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Prompt", "--prompt", "-p") { $userPrompt = $ArgsList[$i+1] }
        }
    }

    if ($file) {
        $file = $file.Trim('"', "'", " ")
    }

    $isWebUrl = ($file -and $file -match '^https?://')
    $isLocalFile = ($file -and (Test-Path $file))

    if (-not $isWebUrl -and -not $isLocalFile) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [08] Vork Estudio y Eliminador / Modificador de Fondo IA${Reset}"
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

    if (-not $mode) {
        $bgOptions = @(
            @{ Value = "prompt";      Label = "[1] Generar nuevo fondo con IA (Escribe un prompt descriptivo)" },
            @{ Value = "transparent"; Label = "[2] Transparente (Aislamiento de silueta PNG alfa puro)" },
            @{ Value = "color";       Label = "[3] Fondo Blanco Studio (Ideal para e-commerce y catálogo)" },
            @{ Value = "black";       Label = "[4] Fondo Negro Cine (Alto contraste dramático)" }
        )

        $chosenBg = Select-InteractiveOption -PromptTitle "Selecciona cómo deseas modificar el fondo de la imagen:" -Options $bgOptions -DefaultIndex 0
        if ($chosenBg) { $mode = $chosenBg } else { $mode = "prompt" }
    }

    if ($mode -eq "prompt" -and -not $userPrompt) {
        Write-Host "  ${Lead}│${Reset} ${White}Escribe el prompt del fondo que deseas generar con IA:${Reset}"
        Write-Host "  ${Lead}│${Reset} ${LeadLight}(Ej: playa paradisíaca al atardecer, oficina cyberpunk moderna, etc.)${Reset}"
        $pInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if ($pInput -and $pInput.Trim()) {
            $userPrompt = $pInput.Trim()
        } else {
            $userPrompt = "modern minimalist photography studio with warm lighting and plants"
        }
    }

    if (-not $out) {
        $ext = if ($mode -eq "transparent") { "png" } else { "jpg" }
        if ($isLocalFile) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $suffix = if ($mode -eq "prompt") { "_fondo_ia" } else { "_nobg" }
            $out = "${baseName}${suffix}.$ext"
        } else {
            $out = if ($mode -eq "prompt") { "fondo_ia.$ext" } else { "sin_fondo.$ext" }
        }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [08] VORK ESTUDIO Y FONDO IA (NEURAL) ──────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset   $White$file$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Modo:$Reset     $Yellow$mode$Reset"
    if ($userPrompt) {
        Write-Host "  $Cyan│$Reset  $Gray Prompt:$Reset   $Cyan`"$userPrompt`"$Reset"
    }
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $bodyMap = @{ mode = $mode }
    if ($userPrompt) {
        $bodyMap["prompt"] = $userPrompt
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
            Write-Host "  $Cyan│$Reset  ${LeadLight}Aislando silueta con BRIA RMBG 1.4...${Reset}"
            Write-Host "  $Cyan│$Reset  ${LeadLight}Generando fondo fotográfico con FLUX.1 Neural...${Reset}"
        } else {
            Write-Host "  $Cyan│$Reset  ${LeadLight}Procesando silueta con IA neuronal...${Reset}"
        }

        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/image/download?id=$($res.id)" }

        Write-Host "  $Cyan│$Reset  $Green✓ Procesamiento de fondo completado exitosamente.$Reset"
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 90
            $resolvedOut = (Resolve-Path $out).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } catch {
            Write-Host "  $Cyan│$Reset  $Yellow URL de descarga:$Reset $White$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Fondo IA]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
