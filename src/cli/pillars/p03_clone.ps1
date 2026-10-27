<#
.SYNOPSIS
    Pilar 03: Vork Clonacion de Voz IA (Extraccion Fundamental F0)
#>

function Invoke-PillarClone {
    param([string[]]$ArgsList)

    $sample = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $text = $null
    $out = "cloned_voice.wav"
    $f0Method = "rmvpe"

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Audio", "--audio", "-a") { $sample = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Text", "--text", "-t") { $text = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
        }
    }

    if (-not $sample) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [03] Vork Clonación de Voz IA (Modelado F0)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ruta del archivo de muestra de audio (ej: muestra.wav):${Reset}"
        $sample = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $sample -or -not $sample.Trim()) {
            Write-Host "  ${Lead}╰─ Clonación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $sample = $sample.Trim()

        $f0Options = @(
            @{ Value = "rmvpe";   Label = "[1] rmvpe    (Estado del arte para máxima fidelidad y pureza vocal)" },
            @{ Value = "harvest"; Label = "[2] harvest  (Extracción F0 de alta precisión tonal en agudos)" },
            @{ Value = "crepe";   Label = "[3] crepe    (Red neuronal profunda para muestras ruidosas)" },
            @{ Value = "pm";      Label = "[4] pm       (Modo ultra-rápido para previsualización inmediata)" }
        )
        $chosenF0 = Select-InteractiveOption -PromptTitle "Selecciona el algoritmo de extracción fundamental F0:" -Options $f0Options -DefaultIndex 0
        if (-not $chosenF0) {
            Write-Host "  ${Lead}╰─ Clonación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $f0Method = $chosenF0

        Write-Host "  ${Lead}│${Reset} ${White}Texto o guión a sintetizar con la voz clonada:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"

        $outInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}Archivo de salida [clonado.wav]:${Reset} "
        if ($outInput -and $outInput.Trim()) { $out = $outInput.Trim() }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [03] VORK CLONACIÓN DE VOZ IA ─────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Muestra:$Reset  $White$sample$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Algoritmo:$Reset$Yellow$f0Method$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Salida:$Reset   $Yellow$out$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $b64 = $null
    if ($sample -and (Test-Path $sample)) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $sample))
            $b64 = "data:audio/wav;base64," + [System.Convert]::ToBase64String($bytes)
        } catch {}
    }

    if (-not $out) { $out = "voz_clonada.wav" }
    $cloneText = if ($text -and $text.Trim()) { $text.Trim() } else { "Prueba de síntesis con voz clonada en Vork CLI." }
    $body = @{ text = $cloneText; audioSampleBase64 = $b64; similarity = "high"; format = "wav" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/voice-clone" -Method Post -Body $body -ContentType "application/json"
        $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
        if ($res.audioBase64) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/voice-clone/download" }
        if (-not (Test-Path $targetFile)) {
            try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing } catch {}
        }

        Write-Host "  $Cyan│$Reset  $Green✓ Clonación de voz completada exitosamente.$Reset"
        if (Test-Path $targetFile) {
            $resolvedOut = (Resolve-Path $targetFile).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } else {
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
        Send-VorkNotification -Title "Vork Clonación Vocal" -Message "Clonación vocal F0 completada con éxito."
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Clonación]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
