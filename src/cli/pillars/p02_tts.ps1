<#
.SYNOPSIS
    Pilar 02: Vork Texto a Voz Neuronal (TTS Studio con 24 voces humanas)
#>

function Invoke-PillarTTS {
    param([string[]]$ArgsList)

    $text = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $voice = "es-ES-AlvaroNeural"
    $out = "tts_output.mp3"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Voice", "--voice", "-v") { $voice = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1] }
        }
    }

    if (-not $text) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [02] Vork Texto a Voz Neuronal (TTS Studio)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto a sintetizar:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $text -or -not $text.Trim()) {
            Write-Host "  ${Lead}╰─ Síntesis cancelada.${Reset}"
            Write-Host ""
            return
        }
        $text = $text.Trim()

        $chosen = Select-InteractiveTTSVoice -PromptTitle "Selecciona el idioma y la voz neuronal:" -DefaultLang "Español" -DefaultVoiceId "es-ES-alvaro"
        if (-not $chosen) {
            Write-Host "  ${Lead}╰─ Síntesis cancelada.${Reset}"
            Write-Host ""
            return
        }

        $voice = $chosen.EdgeVoice
        $voiceDisplay = "$($chosen.Name) ($($chosen.Country) · $($chosen.Gender))"
        $out = if ($out) { $out } else { "voz.mp3" }
    } else {
        $voiceDisplay = $voice
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [02] VORK NEURAL TTS ────────────────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Voz:$Reset     $Yellow$voiceDisplay$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Salida:$Reset  $White$out$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    if (-not $out) { $out = "audio_tts.mp3" }

    $body = @{ text = $text; voice = $voice; outputFormat = "audio-24khz-48kbitrate-mono-mp3" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/tts" -Method Post -Body $body -ContentType "application/json"
        $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }
        if ($res.audioBase64) {
            try {
                $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
            } catch {}
        }
        $dlUrl = if ($res.downloadUrl) { "$ApiBase$($res.downloadUrl)" } else { "$ApiBase/api/tts/download?file=$out" }
        if (-not (Test-Path $targetFile)) {
            try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing } catch {}
        }

        Write-Host "  $Cyan│$Reset  $Green✓ Síntesis vocal completada con éxito.$Reset"
        if (Test-Path $targetFile) {
            $resolvedOut = (Resolve-Path $targetFile).Path
            Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        } else {
            Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlUrl$Reset"
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error TTS]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
