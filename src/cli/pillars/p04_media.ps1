<#
.SYNOPSIS
    Pilar 04: Vork Conversor Multimedia Universal (YouTube, TikTok, IG a MP3/MP4)
#>

function Invoke-PillarMedia {
    param([string[]]$ArgsList)

    $url = $null
    $fmt = $null
    $quality = $null
    $hasExplicitFormat = $false

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Format", "--format", "-f") { $fmt = $ArgsList[$i+1]; $hasExplicitFormat = $true; $i++ }
            elseif ($ArgsList[$i] -in "-Quality", "--quality", "-q") { $quality = $ArgsList[$i+1]; $i++ }
            elseif (-not $url -and -not $ArgsList[$i].StartsWith("-")) { $url = $ArgsList[$i] }
        }
    }

    if (-not $url) {
        Write-VorkSectionHeader -Title "Conversor multimedia" -Subtitle "YouTube · TikTok · Instagram · Reels"
        $url = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $url -or -not $url.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
            Write-Host ""
            return
        }
        $url = $url.Trim()
    }

    if (-not $hasExplicitFormat) {
        if (-not $fmt) {
            $fmt = Select-VorkMediaFormatChoice -PromptTitle "Formato de salida"
            if (-not $fmt) {
                Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
                Write-Host ""
                return
            }
        }

        $quality = Select-VorkMediaQualityChoice -Format $fmt -PromptTitle "Calidad para $($fmt.ToUpper())"
        if (-not $quality) {
            Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
            Write-Host ""
            return
        }
    } else {
        if (-not $quality) {
            $quality = Select-VorkMediaQualityChoice -Format $fmt -PromptTitle "Calidad para $($fmt.ToUpper())"
            if (-not $quality) {
                $quality = if ($fmt -eq "mp3") { "320k" } elseif ($fmt -eq "wav") { "lossless" } else { "720p" }
            }
        }
    }

    $platformName = Get-VorkMediaPlatformName -Url $url
    Write-VorkSectionHeader -Title "Procesando conversión"
    Write-VorkInfoRow -Label "Plataforma" -Value $platformName -ValueColor $Yellow
    Write-VorkInfoRow -Label "URL" -Value $url
    Write-VorkInfoRow -Label "Formato" -Value "$($fmt.ToUpper())  ·  $quality" -ValueColor $Cyan
    Write-VorkSectionRule

    $body = @{ url = $url; format = $fmt; quality = $quality } | ConvertTo-Json
    $endpoint = "$ApiBase/api/media/convert"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        try {
            Write-Host "    ${LeadLight}Progreso${Reset} [${Gray}$([string]::new([char]0x2591, $barLen))${Reset}]   0%  ${LeadLight}Iniciando...${Reset}"
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
                $pct = if ($elapsed -lt 1.5) {
                    [Math]::Min(25, 5 + [int]($elapsed * 13))
                } elseif ($elapsed -lt 4.0) {
                    [Math]::Min(55, 25 + [int](($elapsed - 1.5) * 12))
                } elseif ($elapsed -lt 7.0) {
                    [Math]::Min(80, 55 + [int](($elapsed - 4.0) * 8))
                } elseif ($elapsed -lt 15.0) {
                    [Math]::Min(95, 80 + [int](($elapsed - 7.0) * 1.8))
                } else {
                    [Math]::Min(98, 95 + [int](($elapsed - 15.0) * 0.2))
                }

                $phase = if ($pct -lt 25) {
                    "Conectando..."
                } elseif ($pct -lt 55) {
                    "Descargando flujo..."
                } elseif ($pct -lt 80) {
                    "Codificando a $fmt ($quality)..."
                } else {
                    "Finalizando contenedor..."
                }

                $filledLen = [Math]::Floor(($pct / 100) * $barLen)
                $emptyLen = $barLen - $filledLen
                $filled = [string]::new([char]0x2588, $filledLen)
                $empty = [string]::new([char]0x2591, $emptyLen)
                $pctStr = ($pct.ToString() + "%").PadLeft(4)

                if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                    try { [Console]::SetCursorPosition(0, $pRow) } catch { }
                }
                Write-Host "`r$ClrLine    ${LeadLight}Progreso${Reset} [${Cyan}$filled${Gray}$empty${Reset}] $Yellow$pctStr${Reset}  ${LeadLight}$phase${Reset}" -NoNewline

                Start-Sleep -Milliseconds 120
            }

            if ($task.IsFaulted) {
                throw $task.Exception.InnerException
            }

            $filled100 = [string]::new([char]0x2588, $barLen)
            if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                try { [Console]::SetCursorPosition(0, $pRow) } catch { }
            }
            Write-Host "`r$ClrLine    ${LeadLight}Progreso${Reset} [${Cyan}$filled100${Reset}] ${Green}100%${Reset}  ${Green}Completado${Reset}"

            $jsonStr = $task.Result.Content.ReadAsStringAsync().Result
            try { $res = $jsonStr | ConvertFrom-Json } catch { }
        } else {
            try {
                $res = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json"
            } catch { }
        }

        $isLocalConversion = $false
        # Fallback local resiliente si la nube falla o devuelve error (por ejemplo por restricción de IP en Instagram)
        if (-not $res -or $res.status -eq "error" -or (-not $res.downloadUrl -and -not $res.directVideoUrl -and -not $res.directAudioUrl)) {
            $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
            $possibleEngines = @(
                "$PSScriptRoot\..\..\utils\mediaEngine.js",
                "$HOME\Videos\Visual Studio Code\CloudTranslator\src\utils\mediaEngine.js",
                "C:\Users\isaki\Videos\Visual Studio Code\CloudTranslator\src\utils\mediaEngine.js"
            )
            $engineJs = $possibleEngines | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($nodeCmd -and $engineJs) {
                try {
                    $normEngine = ($engineJs -replace '\\', '/')
                    $jsCode = "const { processConversion } = require('$normEngine'); processConversion({ url: '$url', format: '$fmt', quality: '$quality' }).then(r => console.log(JSON.stringify(r))).catch(e => console.error(JSON.stringify({ status: 'error', error: e.message })));"
                    $localOut = & $nodeCmd.Source -e $jsCode 2>&1
                    $parsed = ($localOut | Out-String).Trim() | ConvertFrom-Json
                    if ($parsed -and $parsed.status -eq "success") {
                        $res = $parsed
                        $isLocalConversion = $true
                    }
                } catch { }
            }
        }

        if (-not $res -or $res.status -eq "error" -or (-not $res.downloadUrl -and -not $res.directVideoUrl -and -not $res.directAudioUrl)) {
            $errDetail = if ($res -and $res.error) { $res.error } else { "No se pudo procesar la conversión a $($fmt.ToUpper()) ($quality) para este enlace. Por favor verifique el enlace e intente nuevamente." }
            Write-VorkStatusLine -Kind error -Text "Error multimedia" -Detail $errDetail
            Write-VorkSectionRule
        } else {
            Write-VorkStatusLine -Kind ok -Text "Conversión multimedia completada"
            $localFile = if ($res.filename) { $res.filename } else { "media_output.$fmt" }

            # En caso de conversión local, resolver el archivo físico existente
            $cachePaths = @(
                "C:\Users\isaki\Videos\Visual Studio Code\CloudTranslator\data\media_cache\$($res.id).$fmt",
                "$PSScriptRoot\..\..\..\data\media_cache\$($res.id).$fmt"
            )
            $foundCache = $cachePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

            $dlFull = if ($isLocalConversion) {
                if ($res.directVideoUrl) { $res.directVideoUrl } elseif ($res.directAudioUrl) { $res.directAudioUrl } else { "" }
            } else {
                if ($res.downloadUrl -and $res.downloadUrl.StartsWith("http")) {
                    $res.downloadUrl
                } elseif ($res.downloadUrl) {
                    "$ApiBase$($res.downloadUrl)"
                } elseif ($res.directVideoUrl) {
                    $res.directVideoUrl
                } else {
                    $res.directAudioUrl
                }
            }

            $videoFull = if ($res.videoStreamUrl -and $res.videoStreamUrl.StartsWith("http")) {
                $res.videoStreamUrl
            } elseif ($res.videoStreamUrl) {
                "$ApiBase$($res.videoStreamUrl)"
            } elseif ($res.directVideoUrl) {
                $res.directVideoUrl
            } else {
                "$ApiBase/api/media/stream?id=$($res.id)&type=video"
            }

            $audioFull = if ($isLocalConversion) {
                if ($res.directAudioUrl) { $res.directAudioUrl } elseif ($res.directVideoUrl) { $res.directVideoUrl } else { "" }
            } else {
                if ($res.audioStreamUrl -and $res.audioStreamUrl.StartsWith("http")) {
                    $res.audioStreamUrl
                } elseif ($res.audioStreamUrl) {
                    "$ApiBase$($res.audioStreamUrl)"
                } elseif ($res.directAudioUrl) {
                    $res.directAudioUrl
                } else {
                    "$ApiBase/api/media/stream?id=$($res.id)&type=audio"
                }
            }

            $outputMode = Select-VorkMediaOutputAction -PromptTitle "Entrega del archivo" -Format $fmt
            if (-not $outputMode) {
                Write-VorkStatusLine -Kind warn -Text "Conversión cancelada."
                Write-VorkSectionRule
                Write-Host ""
                return
            }

            $hasLocal = $outputMode -in @("local", "local_video", "local_audio", "local_download", "all")
            $hasDownload = $outputMode -in @("download", "local_download", "all")
            $hasVideoStream = ($fmt -eq "mp4") -and ($outputMode -in @("video_stream", "local_video", "all"))
            $hasAudioStream = ($fmt -in @("mp3", "wav")) -and ($outputMode -in @("audio_stream", "local_audio", "all"))

            if ($hasLocal) {
                try {
                    if ($foundCache) {
                        Copy-Item -Path $foundCache -Destination $localFile -Force
                    } elseif ($dlFull -and $dlFull.StartsWith("http")) {
                        Invoke-WebRequest -Uri $dlFull -OutFile $localFile -UseBasicParsing -TimeoutSec 120
                    }
                    if (Test-Path $localFile) {
                        $resolvedOut = (Resolve-Path $localFile).Path
                        Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
                    }
                } catch {
                    if ($dlFull) { Write-VorkInfoRow -Label "Descarga" -Value $dlFull -ValueColor $Yellow }
                }
            }

            if ($hasDownload -and -not $isLocalConversion) {
                if ($dlFull) { Write-VorkInfoRow -Label "Descarga" -Value $dlFull -ValueColor $Yellow }
            }

            if ($hasVideoStream) {
                if ($videoFull) {
                    Write-VorkInfoRow -Label "Video" -Value $videoFull -ValueColor $Purple
                } elseif (Test-Path $localFile) {
                    Write-VorkInfoRow -Label "Video" -Value (Resolve-Path $localFile).Path -ValueColor $Purple
                }
            }

            if ($hasAudioStream) {
                if ($audioFull) {
                    Write-VorkInfoRow -Label "Audio" -Value $audioFull -ValueColor $Cyan
                } elseif (Test-Path $localFile) {
                    Write-VorkInfoRow -Label "Audio" -Value (Resolve-Path $localFile).Path -ValueColor $Cyan
                }
            }

            Write-VorkSectionRule
            Send-VorkNotification -Title "Vork Conversor Multimedia" -Message "Conversión a $fmt ($quality) completada con éxito."
        }
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error multimedia" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
