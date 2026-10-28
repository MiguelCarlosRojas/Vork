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
        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/tts/download?file=$out" }
        $stUrl = if ($res.streamUrl) { if ($res.streamUrl.StartsWith("http")) { $res.streamUrl } else { "$ApiBase$($res.streamUrl)" } } else { "$ApiBase/api/tts/stream?file=$out" }
        $videoFull = if ($res.videoStreamUrl) { if ($res.videoStreamUrl.StartsWith("http")) { $res.videoStreamUrl } else { "$ApiBase$($res.videoStreamUrl)" } } else { $stUrl }
        $audioFull = if ($res.audioStreamUrl) { if ($res.audioStreamUrl.StartsWith("http")) { $res.audioStreamUrl } else { "$ApiBase$($res.audioStreamUrl)" } } else { $stUrl }

        Write-Host "  $Cyan│$Reset  $Green✓ Síntesis vocal completada con éxito.$Reset"
        $outputMode = Select-VorkMediaOutputAction -PromptTitle "Selecciona cómo deseas obtener el audio sintetizado:"
        if (-not $outputMode) { $outputMode = "all" }

        $hasLocal = $outputMode -in @("local", "local_video", "local_audio", "local_download", "local_stream", "all")
        $hasDownload = $outputMode -in @("download", "local_download", "download_stream", "all")
        $hasVideoStream = $outputMode -in @("video_stream", "local_video", "video_audio", "stream", "local_stream", "download_stream", "all")
        $hasAudioStream = $outputMode -in @("audio_stream", "local_audio", "video_audio", "stream", "local_stream", "download_stream", "all")

        if ($hasLocal) {
            if ($res.audioBase64) {
                try {
                    $rawB64 = $res.audioBase64 -replace '^data:audio/[^;]+;base64,', ''
                    [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
                } catch {}
            }
            if (-not (Test-Path $targetFile)) {
                try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing -TimeoutSec 120 } catch {}
            }
            if (Test-Path $targetFile) {
                $resolvedOut = (Resolve-Path $targetFile).Path
                Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
            }
        }

        if ($hasDownload) {
            Write-Host "  $Cyan│$Reset  $Yellow✓ Descarga:$Reset       $White$dlUrl$Reset"
        }

        if ($hasVideoStream -and $videoFull) {
            Write-Host "  $Cyan│$Reset  $Magenta✓ Stream Video:$Reset   $White$videoFull$Reset"
        }

        if ($hasAudioStream -and $audioFull) {
            Write-Host "  $Cyan│$Reset  $Cyan✓ Stream Música:$Reset  $White$audioFull$Reset"
        }

        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
        Send-VorkNotification -Title "Vork Síntesis TTS" -Message "Audio de voz neuronal generado con éxito."
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error TTS]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
