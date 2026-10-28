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
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [04] Vork Conversor Multimedia Universal${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la URL del video (YouTube, TikTok, Reels, IG):${Reset}"
        $url = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $url -or -not $url.Trim()) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
        $url = $url.Trim()
    }

    if (-not $hasExplicitFormat) {
        if (-not $fmt) {
            $fmt = Select-VorkMediaFormatChoice -PromptTitle "Selecciona el formato de salida:"
            if (-not $fmt) {
                Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
                Write-Host ""
                return
            }
        }

        $quality = Select-VorkMediaQualityChoice -Format $fmt -PromptTitle "Selecciona la calidad deseada para $($fmt.ToUpper()):"
        if (-not $quality) {
            Write-Host "  ${Lead}╰─ Conversión cancelada.${Reset}"
            Write-Host ""
            return
        }
    } else {
        if (-not $quality) {
            $quality = Select-VorkMediaQualityChoice -Format $fmt -PromptTitle "Selecciona la calidad deseada para $($fmt.ToUpper()):"
            if (-not $quality) {
                $quality = if ($fmt -eq "mp3") { "320k" } elseif ($fmt -eq "wav") { "lossless" } else { "720p" }
            }
        }
    }

    $platformName = Get-VorkMediaPlatformName -Url $url
    Write-Host ""
    Write-Host "  $Cyan╭─ [04] VORK CONVERSOR MULTIMEDIA ──────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Plataforma:$Reset  $Yellow${Bold}$platformName$Reset"
    Write-Host "  $Cyan│$Reset  $Gray URL:$Reset         $White$url$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Formato:$Reset     $Cyan${Bold}$($fmt.ToUpper())$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Calidad:$Reset     $Yellow$quality$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"

    $body = @{ url = $url; format = $fmt; quality = $quality } | ConvertTo-Json
    $endpoint = "$ApiBase/api/media/convert"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        try {
            Write-Host "  $Cyan│$Reset  ${White}Progreso:${Reset} [${Gray}$([string]::new([char]0x2591, $barLen))${Reset}]   0%  ${LeadLight}Iniciando...${Reset}"
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
                Write-Host "`r$ClrLine  $Cyan│$Reset  ${White}Progreso:${Reset} [${Cyan}$filled${Gray}$empty${Reset}] $Yellow$pctStr$Reset  ${LeadLight}$phase${Reset}" -NoNewline

                Start-Sleep -Milliseconds 120
            }

            if ($task.IsFaulted) {
                throw $task.Exception.InnerException
            }

            # 100% Finalizado
            $filled100 = [string]::new([char]0x2588, $barLen)
            if ($pRow -ge 0 -and $pRow -lt [Console]::BufferHeight) {
                try { [Console]::SetCursorPosition(0, $pRow) } catch { }
            }
            Write-Host "`r$ClrLine  $Cyan│$Reset  ${White}Progreso:${Reset} [${Cyan}$filled100${Reset}] ${Green}100%${Reset}  ${Green}Completado${Reset}"

            $jsonStr = $task.Result.Content.ReadAsStringAsync().Result
            $res = $jsonStr | ConvertFrom-Json
        } else {
            # Fallback síncrono si HttpClient no estuviera disponible
            $res = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json"
        }

        if ($res.status -eq "error" -or (-not $res.downloadUrl -and $res.error)) {
            Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
            Write-Host "  $Cyan│$Reset  ${Coral}[Error Multimedia]:${Reset} $($res.error)"
            Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
        } else {
            Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
            Write-Host "  $Cyan│$Reset  $Green✓ Conversión multimedia completada exitosamente.$Reset"
            $dlFull = if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
            $stFull = if ($res.streamUrl -and $res.streamUrl.StartsWith("http")) { $res.streamUrl } elseif ($res.streamUrl) { "$ApiBase$($res.streamUrl)" } else { "$ApiBase/api/media/stream?id=$($res.id)" }
            $localFile = if ($res.filename) { $res.filename } else { "media_output.$fmt" }

            $outputMode = Select-VorkMediaOutputAction -PromptTitle "Selecciona cómo deseas obtener el archivo convertido:"
            if (-not $outputMode) { $outputMode = "all" }

            $hasLocal = $outputMode -in @("local", "local_stream", "local_download", "all")
            $hasDownload = $outputMode -in @("download", "local_download", "download_stream", "all")
            $hasStream = $outputMode -in @("stream", "local_stream", "download_stream", "all")

            if ($hasLocal) {
                try {
                    Invoke-WebRequest -Uri $dlFull -OutFile $localFile -UseBasicParsing -TimeoutSec 120
                    $resolvedOut = (Resolve-Path $localFile).Path
                    Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
                } catch {
                    Write-Host "  $Cyan│$Reset    Descarga: $Yellow$dlFull$Reset"
                }
            }

            if ($hasDownload) {
                Write-Host "  $Cyan│$Reset  $Yellow✓ Descarga:$Reset       $White$dlFull$Reset"
            }

            if ($hasStream) {
                Write-Host "  $Cyan│$Reset  $Cyan✓ Stream:  $Reset       $White$stFull$Reset"
            }

            Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
            Send-VorkNotification -Title "Vork Conversor Multimedia" -Message "Conversión a $fmt ($quality) completada con éxito."
        }
    } catch {
        Write-Host ""
        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
        Write-Host "  $Cyan│$Reset  ${Coral}[Error Multimedia]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
