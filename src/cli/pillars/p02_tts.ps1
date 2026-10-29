<#
.SYNOPSIS
    Pilar 02: Vork Texto a Voz Neuronal (TTS Studio con 24 voces humanas)
#>

function Invoke-PillarTTS {
    param([string[]]$ArgsList)

    $text = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $voice = "es-ES-AlvaroNeural"
    $out = "tts_output.mp3"
    $explicitOut = $false

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Voice", "--voice", "-v") { $voice = $ArgsList[$i+1] }
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1]; $explicitOut = $true }
        }
    }

    if (-not $text) {
        Write-VorkSectionHeader -Title "Texto a voz" -Subtitle "Síntesis neuronal · 24 voces humanas" -RightText "vork · tts"
        $text = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $text -or -not $text.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Síntesis cancelada."
            Write-Host ""
            return
        }
        $text = $text.Trim()

        $chosen = Select-InteractiveTTSVoice -PromptTitle "Idioma y voz neuronal" -DefaultLang "Español" -DefaultVoiceId "es-ES-alvaro"
        if (-not $chosen) {
            Write-VorkStatusLine -Kind warn -Text "Síntesis cancelada."
            Write-Host ""
            return
        }

        $voice = $chosen.EdgeVoice
        $voiceDisplay = "$($chosen.Name) ($($chosen.Country) · $($chosen.Gender))"
        $out = if ($explicitOut) { $out } else { "voz.mp3" }
    } else {
        $voiceDisplay = $voice
    }

    Write-VorkSectionHeader -Title "Procesando síntesis" -RightText "vork · tts"
    Write-VorkInfoRow -Label "Voz" -Value $voiceDisplay -ValueColor $Yellow
    if ($explicitOut) {
        Write-VorkInfoRow -Label "Salida" -Value $out -ValueColor $Cyan
    } else {
        Write-VorkInfoRow -Label "Formato" -Value "MP3  ·  24kHz Neuronal" -ValueColor $Cyan
    }
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind step -Text "Generando audio neuronal"

    if (-not $out) { $out = "audio_tts.mp3" }

    $body = @{ text = $text; voice = $voice; outputFormat = "audio-24khz-48kbitrate-mono-mp3" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/tts" -Method Post -Body $body -ContentType "application/json"
        $targetFile = if ([System.IO.Path]::IsPathRooted($out)) { $out } else { Join-Path (Get-Location) $out }

        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/tts/download?file=$out" }
        $stUrl = if ($res.streamUrl) { if ($res.streamUrl.StartsWith("http")) { $res.streamUrl } else { "$ApiBase$($res.streamUrl)" } } else { "$ApiBase/api/tts/stream?file=$out" }
        $videoFull = if ($res.videoStreamUrl) { if ($res.videoStreamUrl.StartsWith("http")) { $res.videoStreamUrl } else { "$ApiBase$($res.videoStreamUrl)" } } else { $stUrl }
        $audioFull = if ($res.audioStreamUrl) { if ($res.audioStreamUrl.StartsWith("http")) { $res.audioStreamUrl } else { "$ApiBase$($res.audioStreamUrl)" } } else { $stUrl }

        Write-VorkStatusLine -Kind ok -Text "Síntesis vocal completada"
        $outputMode = Select-VorkMediaOutputAction -PromptTitle "Entrega del audio" -Format "mp3"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Entrega cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "local_audio", "local_download", "all")
        $hasDownload = $outputMode -in @("download", "local_download", "all")
        $hasAudioStream = $outputMode -in @("audio_stream", "local_audio", "all")

        if ($hasLocal) {
            if ($res.audioBase64) {
                try {
                    $rawB64 = $res.audioBase64 -replace '^data:audio\/[^;]+;base64,', ''
                    [System.IO.File]::WriteAllBytes($targetFile, [System.Convert]::FromBase64String($rawB64))
                } catch {}
            }
            if (-not (Test-Path $targetFile)) {
                try { Invoke-WebRequest -Uri $dlUrl -OutFile $targetFile -UseBasicParsing -TimeoutSec 120 } catch {}
            }
            if (Test-Path $targetFile) {
                $resolvedOut = (Resolve-Path $targetFile).Path
                Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
            }
        }

        if ($hasDownload) {
            Write-VorkInfoRow -Label "Descarga" -Value $dlUrl -ValueColor $Yellow
        }

        if ($hasVideoStream -and $videoFull) {
            Write-VorkInfoRow -Label "Video" -Value $videoFull -ValueColor $Purple
        }

        if ($hasAudioStream -and $audioFull) {
            Write-VorkInfoRow -Label "Audio" -Value $audioFull -ValueColor $Cyan
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Síntesis TTS" -Message "Audio de voz neuronal generado con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de TTS" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
