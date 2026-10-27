<#
.SYNOPSIS
    Pilar 08: Vork Estudio y Eliminador de Fondo IA (U2-Net / BRIA RMBG)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $out = $null
    $mode = "transparent"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Mode", "--mode", "-m") { $mode = $ArgsList[$i+1] }
        }
    }

    if ($file) {
        $file = $file.Trim('"', "'", " ")
    }

    $isWebUrl = ($file -and $file -match '^https?://')
    $isLocalFile = ($file -and (Test-Path $file))

    if (-not $isWebUrl -and -not $isLocalFile) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [08] Vork Estudio y Eliminador de Fondo IA${Reset}"
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

        $bgOptions = @(
            @{ Value = "transparent"; Label = "[1] Transparente (Aislamiento de silueta PNG alfa puro)" },
            @{ Value = "color";       Label = "[2] Fondo Blanco Studio (Ideal para e-commerce y catálogo)" },
            @{ Value = "black";       Label = "[3] Fondo Negro Cine (Alto contraste dramático)" }
        )

        $chosenBg = Select-InteractiveOption -PromptTitle "Selecciona el modo de procesamiento de fondo:" -Options $bgOptions -DefaultIndex 0
        if ($chosenBg) { $mode = $chosenBg }
    }

    if (-not $out) {
        $ext = if ($mode -eq "color" -or $mode -eq "black") { "jpg" } else { "png" }
        if ($isLocalFile) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $out = "${baseName}_nobg.$ext"
        } else {
            $out = "sin_fondo.$ext"
        }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [08] VORK ESTUDIO Y FONDO IA ──────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Origen:$Reset   $White$file$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Modo:$Reset     $Yellow$mode$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $body = if ($isLocalFile) {
        $resolved = Resolve-Path $file
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $b64 = [System.Convert]::ToBase64String($bytes)
        @{ imageBase64 = "data:image/jpeg;base64,$b64"; mode = $mode } | ConvertTo-Json
    } else {
        @{ url = $file; mode = $mode } | ConvertTo-Json
    }

    try {
        Write-Host "  $Cyan│$Reset  ${LeadLight}Procesando silueta con IA neuronal...${Reset}"
        $res = Invoke-RestMethod -Uri "$ApiBase/api/image/remove-background" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/image/download?id=$($res.id)" }

        Write-Host "  $Cyan│$Reset  $Green✓ Recorte de fondo completado exitosamente.$Reset"
        try {
            Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 60
            $resolvedOut = Resolve-Path $out
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } catch {
            Write-Host "  $Cyan│$Reset  $Yellow URL de descarga:$Reset $White$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Fondo IA]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Wait-VorkGoBack
    Write-Host ""
}
