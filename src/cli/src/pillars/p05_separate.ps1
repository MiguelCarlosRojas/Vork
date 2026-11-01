<#
.SYNOPSIS
    Pilar 05: Vork Separador de Stems (Acapella y Karaoke con Demucs v4)
#>

function Invoke-PillarSeparate {
    param([string[]]$ArgsList)

    $target = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $mode = "2stems"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Mode", "--mode", "-m") { $mode = $ArgsList[$i+1] }
        }
    }

    if (-not $target) {
        Write-VorkSectionHeader -Title "Separación de stems" -Subtitle "Acapella y karaoke con Demucs v4" -RightText "vork · stems"
        $target = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $target -or -not $target.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Separación cancelada."
            Write-Host ""
            return
        }
        $target = $target.Trim()

        $sepOptions = @(
            @{ Value = "2stems";  Label = "2 stems";  Description = "Voz acapella y pista instrumental" },
            @{ Value = "4stems";  Label = "4 stems";  Description = "Voz, batería, bajo y otros instrumentos" },
            @{ Value = "vocals";  Label = "Acapella"; Description = "Aislamiento vocal puro con reducción de ruido" },
            @{ Value = "karaoke"; Label = "Karaoke";  Description = "Instrumental con eliminación estricta de voz" }
        )

        $chosenMode = Select-InteractiveOption -PromptTitle "Modo de separación" -Subtitle "pistas a extraer" -Options $sepOptions -DefaultIndex 0
        if (-not $chosenMode) {
            Write-VorkStatusLine -Kind warn -Text "Separación cancelada."
            Write-Host ""
            return
        }
        $mode = $chosenMode
    }

    Write-VorkSectionHeader -Title "Procesando separación" -RightText "vork · stems"
    Write-VorkInfoRow -Label "Pista" -Value $target
    Write-VorkInfoRow -Label "Modo" -Value $mode -ValueColor $Yellow
    Write-VorkSectionRule

    $isLocal = try { Test-Path $target -PathType Leaf } catch { $false }
    $body = if ($isLocal) {
        $resolved = Resolve-Path $target
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $b64 = [System.Convert]::ToBase64String($bytes)
        $fn = [System.IO.Path]::GetFileName($resolved)
        @{ audioBase64 = $b64; filename = $fn; quality = "320k"; mode = $mode } | ConvertTo-Json
    } else {
        @{ url = $target; quality = "320k"; mode = $mode } | ConvertTo-Json
    }

    $endpoint = "$ApiBase/api/separator/process"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        $emptyBar = [string]::new([char]0x2591, $barLen)
        try {
            Write-Host "    ${LeadLight}Progreso${Reset} [${Gray}$emptyBar${Reset}]   0%  ${LeadLight}Iniciando...${Reset}"
            $pRow = [Console]::CursorTop - 1
        } catch { }

        if ('System.Net.Http.HttpClient' -as [type]) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromMinutes(5)
            $httpContent = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
            $task = $client.PostAsync($endpoint, $httpContent)

            $startTime = [DateTime]::UtcNow

            while (-not $task.IsCompleted) {
                $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
                $pct = if ($elapsed -lt 3.0) {
                    [Math]::Min(25, 5 + [int]($elapsed * 7))
                } elseif ($elapsed -lt 8.0) {
                    [Math]::Min(50, 25 + [int](($elapsed - 3.0) * 5))
                } elseif ($elapsed -lt 18.0) {
                    [Math]::Min(75, 50 + [int](($elapsed - 8.0) * 2.5))
                } elseif ($elapsed -lt 35.0) {
                    [Math]::Min(95, 75 + [int](($elapsed - 18.0) * 1.1))
                } else {
                    [Math]::Min(98, 95 + [int](($elapsed - 35.0) * 0.1))
                }

                $phase = if ($pct -lt 25) {
                    "Descargando pista..."
                } elseif ($pct -lt 50) {
                    "Normalizando espectro acústico..."
                } elseif ($pct -lt 75) {
                    "Separando voz e instrumental con Demucs v4..."
                } else {
                    "Masterizando stems de audio 320 kbps..."
                }

                $filledLen = [Math]::Floor(($pct / 100) * $barLen)
                $unfilledLen = $barLen - $filledLen
                $barStr = [string]::new([char]0x2588, $filledLen) + [string]::new([char]0x2591, $unfilledLen)
                $pctStr = "$pct".PadLeft(3)

                if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                    try {
                        [Console]::SetCursorPosition(0, $pRow)
                        Write-Host "    ${LeadLight}Progreso${Reset} [${Yellow}$barStr${Reset}] $pctStr%  ${LeadLight}$phase${Reset}    $ClrToEnd" -NoNewline
                    } catch { }
                }

                Start-Sleep -Milliseconds 150
            }

            if ($task.IsFaulted) {
                throw $task.Exception.InnerException
            }

            $filled100 = [string]::new([char]0x2588, $barLen)
            if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                try { [Console]::SetCursorPosition(0, $pRow) } catch { }
            }
            Write-Host "`r$ClrLine    ${LeadLight}Progreso${Reset} [${Green}$filled100${Reset}] 100%  ${Green}Completado${Reset}"

            $jsonStr = $task.Result.Content.ReadAsStringAsync().Result
            if (-not $task.Result.IsSuccessStatusCode) {
                $errDetail = $null
                try {
                    $parsedErr = $jsonStr | ConvertFrom-Json
                    if ($parsedErr -and $parsedErr.error) { $errDetail = $parsedErr.error }
                } catch { }
                if (-not $errDetail) {
                    $errDetail = "Error en el servidor ($([int]$task.Result.StatusCode)): $($task.Result.ReasonPhrase)"
                }
                Write-VorkStatusLine -Kind error -Text "Error del separador" -Detail $errDetail
                Write-VorkSectionRule
                return
            }
            $res = try { $jsonStr | ConvertFrom-Json } catch { $null }
        } else {
            $res = try { Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 300 } catch { $null }
        }

        if (-not $res -or $res.status -eq "error" -or $res.error) {
            $errDetail = if ($res -and $res.error) { $res.error } else { "No se pudo completar la separación de stems." }
            Write-VorkStatusLine -Kind error -Text "Error del separador" -Detail $errDetail
            Write-VorkSectionRule
            return
        }

        $vocDl = $null
        $vocSt = $null
        if ($res.vocals) {
            $rawDl = $res.vocals.downloadUrl
            $rawSt = $res.vocals.streamUrl
            if ($rawDl) { $vocDl = if ($rawDl -match '^https?://') { $rawDl } else { "$ApiBase$rawDl" } }
            if ($rawSt) { $vocSt = if ($rawSt -match '^https?://') { $rawSt } else { "$ApiBase$rawSt" } }
        }

        $instDl = $null
        $instSt = $null
        if ($res.instrumental) {
            $rawDl = $res.instrumental.downloadUrl
            $rawSt = $res.instrumental.streamUrl
            if ($rawDl) { $instDl = if ($rawDl -match '^https?://') { $rawDl } else { "$ApiBase$rawDl" } }
            if ($rawSt) { $instSt = if ($rawSt -match '^https?://') { $rawSt } else { "$ApiBase$rawSt" } }
        }

        Write-VorkStatusLine -Kind ok -Text "Separación completada con Demucs v4"

        $outputMode = Select-VorkMediaOutputAction -PromptTitle "Entrega de las pistas" -Format "wav"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Separación cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "local_audio", "local_download", "all")
        $hasDownload = $outputMode -in @("download", "local_download", "all")
        $hasAudioStream = $outputMode -in @("audio_stream", "local_audio", "all")

        if ($mode -eq "vocals") {
            if ($hasLocal -and $vocDl) {
                $localVoc = "vocals.wav"
                try {
                    Invoke-WebRequest -Uri $vocDl -OutFile $localVoc -UseBasicParsing -TimeoutSec 120
                    Write-VorkInfoRow -Label "Guardado" -Value (Resolve-Path $localVoc).Path -ValueColor $Green
                } catch {
                    Write-VorkInfoRow -Label "Descarga" -Value $vocDl -ValueColor $Yellow
                }
            }
            if ($hasDownload -and $vocDl) {
                Write-VorkInfoRow -Label "Descarga" -Value $vocDl -ValueColor $Yellow
            }
            if ($hasVideoStream -and $vocSt) {
                Write-VorkInfoRow -Label "Video" -Value $vocSt -ValueColor $Purple
            }
            if ($hasAudioStream -and $vocSt) {
                Write-VorkInfoRow -Label "Audio" -Value $vocSt -ValueColor $Cyan
            }
        } elseif ($mode -eq "karaoke") {
            if ($hasLocal -and $instDl) {
                $localInst = "instrumental.wav"
                try {
                    Invoke-WebRequest -Uri $instDl -OutFile $localInst -UseBasicParsing -TimeoutSec 120
                    Write-VorkInfoRow -Label "Guardado" -Value (Resolve-Path $localInst).Path -ValueColor $Green
                } catch {
                    Write-VorkInfoRow -Label "Descarga" -Value $instDl -ValueColor $Yellow
                }
            }
            if ($hasDownload -and $instDl) {
                Write-VorkInfoRow -Label "Descarga" -Value $instDl -ValueColor $Yellow
            }
            if ($hasVideoStream -and $instSt) {
                Write-VorkInfoRow -Label "Video" -Value $instSt -ValueColor $Purple
            }
            if ($hasAudioStream -and $instSt) {
                Write-VorkInfoRow -Label "Audio" -Value $instSt -ValueColor $Cyan
            }
        } else {
            if ($hasLocal) {
                if ($vocDl) {
                    $localVoc = "vocals.wav"
                    try {
                        Invoke-WebRequest -Uri $vocDl -OutFile $localVoc -UseBasicParsing -TimeoutSec 120
                        Write-VorkInfoRow -Label "Voz" -Value (Resolve-Path $localVoc).Path -ValueColor $Green
                    } catch {}
                }
                if ($instDl) {
                    $localInst = "instrumental.wav"
                    try {
                        Invoke-WebRequest -Uri $instDl -OutFile $localInst -UseBasicParsing -TimeoutSec 120
                        Write-VorkInfoRow -Label "Instrumental" -Value (Resolve-Path $localInst).Path -ValueColor $Green
                    } catch {}
                }
            }
            if ($hasDownload) {
                if ($vocDl) { Write-VorkInfoRow -Label "Descarga voz" -Value $vocDl -ValueColor $Yellow }
                if ($instDl) { Write-VorkInfoRow -Label "Descarga inst" -Value $instDl -ValueColor $Yellow }
            }
            if ($hasVideoStream) {
                $stVid = if ($vocSt) { $vocSt } else { $instSt }
                if ($stVid) { Write-VorkInfoRow -Label "Video" -Value $stVid -ValueColor $Purple }
            }
            if ($hasAudioStream) {
                if ($vocSt) { Write-VorkInfoRow -Label "Audio voz" -Value $vocSt -ValueColor $Cyan }
                if ($instSt) { Write-VorkInfoRow -Label "Audio inst" -Value $instSt -ValueColor $Cyan }
            }
        }
        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Separador de Stems" -Message "Aislamiento de pistas completado con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error del separador" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
