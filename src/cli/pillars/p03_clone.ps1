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
        Write-VorkSectionHeader -Title "Clonación de voz" -Subtitle "Muestra de audio · modelado F0" -RightText "vork · voice clone"
        $sample = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $sample -or -not $sample.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Clonación cancelada."
            Write-Host ""
            return
        }
        $sample = $sample.Trim()

        $f0Options = @(
            @{ Value = "rmvpe";   Label = "rmvpe";   Description = "Máxima fidelidad y pureza vocal" },
            @{ Value = "harvest"; Label = "harvest"; Description = "Alta precisión tonal en agudos" },
            @{ Value = "crepe";   Label = "crepe";   Description = "Red neuronal para muestras con ruido" },
            @{ Value = "pm";      Label = "pm";      Description = "Modo ultrarrápido de previsualización" }
        )
        $chosenF0 = Select-InteractiveOption -PromptTitle "Algoritmo de extracción F0" -Subtitle "modelado de la voz" -Options $f0Options -DefaultIndex 0
        if (-not $chosenF0) {
            Write-VorkStatusLine -Kind warn -Text "Clonación cancelada."
            Write-Host ""
            return
        }
        $f0Method = $chosenF0

        Write-VorkSectionHeader -Title "Guión y salida" -RightText "vork · voice clone"
        Write-VorkInfoRow -Label "Guión" -Value "Texto para la voz clonada · enter para usar una frase de prueba" -ValueColor $LeadLight
        $text = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        Write-VorkInfoRow -Label "Salida" -Value "Archivo de audio destino [clonado.wav]" -ValueColor $LeadLight
        $outInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if ($outInput -and $outInput.Trim()) { $out = $outInput.Trim() }
    }

    Write-VorkSectionHeader -Title "Procesando clonación" -RightText "vork · voice clone"
    Write-VorkInfoRow -Label "Muestra" -Value $sample
    Write-VorkInfoRow -Label "Algoritmo" -Value $f0Method -ValueColor $Yellow
    Write-VorkInfoRow -Label "Salida" -Value $out -ValueColor $Yellow
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind step -Text "Modelando la voz y sintetizando el audio"

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
        $dlUrl = if ($res.downloadUrl) { if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" } } else { "$ApiBase/api/voice-clone/download" }
        $stUrl = if ($res.streamUrl) { if ($res.streamUrl.StartsWith("http")) { $res.streamUrl } else { "$ApiBase$($res.streamUrl)" } } else { "$ApiBase/api/voice-clone/stream" }
        $videoFull = if ($res.videoStreamUrl) { if ($res.videoStreamUrl.StartsWith("http")) { $res.videoStreamUrl } else { "$ApiBase$($res.videoStreamUrl)" } } else { $stUrl }
        $audioFull = if ($res.audioStreamUrl) { if ($res.audioStreamUrl.StartsWith("http")) { $res.audioStreamUrl } else { "$ApiBase$($res.audioStreamUrl)" } } else { $stUrl }

        Write-VorkStatusLine -Kind ok -Text "Clonación de voz completada"
        $outputMode = Select-VorkMediaOutputAction -PromptTitle "Entrega de la voz clonada"
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
        Send-VorkNotification -Title "Vork Clonación Vocal" -Message "Clonación vocal F0 completada con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de clonación" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
