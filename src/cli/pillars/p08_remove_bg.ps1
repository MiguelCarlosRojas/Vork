<#
.SYNOPSIS
    Pilar 08: Vork Eliminador y Modificador de Fondo IA (Aislamiento de Silueta Neuronal)
#>

function Invoke-PillarRemoveBg {
    param([string[]]$ArgsList)

    $file = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $out = $null

    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $out = $ArgsList[$i+1]; $i++; continue }
        }
    }

    if ($file) {
        $file = $file.Trim('"', "'", " ")
    }

    $isWebUrl = ($file -and $file -match '^https?://')
    $isLocalFile = ($file -and (Test-Path $file))

    if (-not $isWebUrl -and -not $isLocalFile) {
        Write-VorkSectionHeader -Title "Eliminación de fondo IA" -Subtitle "Ruta local o URL de la imagen" -RightText "vork · fondo ia"
        $fileInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $fileInput -or -not $fileInput.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada."
            Write-Host ""
            return
        }
        $file = $fileInput.Trim('"', "'", " ")
        $isWebUrl = ($file -match '^https?://')
        $isLocalFile = (Test-Path $file)

        if (-not $isWebUrl -and -not $isLocalFile) {
            Write-VorkStatusLine -Kind error -Text "Archivo o URL no encontrado" -Detail $file
            Write-Host ""
            return
        }
    }

    $instruction = $null
    if ($ArgsList -and $ArgsList.Length -gt 1) {
        $cleanArgs = @()
        for ($i=1; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-Out", "--out", "-o") { $i++; continue }
            $cleanArgs += $ArgsList[$i]
        }
        if ($cleanArgs.Count -gt 0) { $instruction = ($cleanArgs -join " ").Trim() }
    }

    if (-not $instruction) {
        Write-VorkSectionHeader -Title "Instrucción de edición IA" -Subtitle "describe qué eliminar o agregar · enter para fondo transparente" -RightText "vork · imagen ia"
        Write-VorkInfoRow -Label "Ejemplos" -Value "eliminar celular de la mano, poner gafas de sol, quitar fondo..." -ValueColor $LeadLight
        $userPrompt = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if ($userPrompt -and $userPrompt.Trim()) {
            $instruction = $userPrompt.Trim()
        }
    }

    $isOnlyBg = (-not $instruction -or $instruction -match '^(quitar|eliminar|borrar)?\s*(el\s*)?(fondo)?\s*$' -or $instruction -eq "transparent")
    $mode = if ($isOnlyBg) { "transparent" } else { "edit" }
    $ext = "png"
    if (-not $out) {
        if ($isLocalFile) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $suffix = if ($isOnlyBg) { "_sin_fondo" } else { "_editado" }
            $out = "${baseName}${suffix}.$ext"
        } else {
            $out = if ($isOnlyBg) { "sin_fondo.$ext" } else { "editado.$ext" }
        }
    }

    $modeLabel = if ($isOnlyBg) { "Eliminar fondo (Silueta PNG con canal alfa)" } else { "Edición IA: $instruction" }

    Write-VorkSectionHeader -Title "Procesando edición IA" -RightText "vork · imagen ia"
    Write-VorkInfoRow -Label "Origen" -Value $file
    Write-VorkInfoRow -Label "Operación" -Value $modeLabel -ValueColor $Cyan
    Write-VorkSectionRule

    $bodyMap = @{
        mode = $mode
        instruction = if ($instruction) { $instruction } else { "remove background, transparent" }
        prompt = if ($instruction) { $instruction } else { "remove background, transparent" }
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
    $endpoint = "$ApiBase/api/image/remove-background"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        try {
            Write-Host "    ${LeadLight}Progreso${Reset} [${Gray}$([string]::new([char]0x2591, $barLen))${Reset}]   0%  ${LeadLight}Conectando con IA neuronal...${Reset}"
            $pRow = [Console]::CursorTop - 1
        } catch { }

        if ('System.Net.Http.HttpClient' -as [type]) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromMinutes(3)
            $httpContent = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
            $task = $client.PostAsync($endpoint, $httpContent)

            $startTime = [DateTime]::UtcNow

            while (-not $task.IsCompleted) {
                $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
                $pct = if ($elapsed -lt 1.5) {
                    [Math]::Min(25, 5 + [int]($elapsed * 13))
                } elseif ($elapsed -lt 4.0) {
                    [Math]::Min(55, 25 + [int](($elapsed - 1.5) * 12))
                } elseif ($elapsed -lt 8.0) {
                    [Math]::Min(80, 55 + [int](($elapsed - 4.0) * 6))
                } elseif ($elapsed -lt 16.0) {
                    [Math]::Min(95, 80 + [int](($elapsed - 8.0) * 1.8))
                } else {
                    [Math]::Min(98, 95 + [int](($elapsed - 16.0) * 0.2))
                }

                $phase = if ($pct -lt 30) {
                    "Descargando y preparando imagen..."
                } elseif ($pct -lt 65) {
                    "Procesando con IA contextual..."
                } elseif ($pct -lt 85) {
                    "Aplicando transformaciones y silueta..."
                } else {
                    "Componiendo formato final $ext..."
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
            $res = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
        }

        # Fallback local resiliente con Python rembg si la nube falla
        if (-not $res -or $res.status -eq "error") {
            $pythonCmd = Get-Command "python" -ErrorAction SilentlyContinue
            $possibleStudios = @(
                "$PSScriptRoot\..\..\utils\ai_image_studio.py",
                "C:\Users\isaki\Videos\Visual Studio Code\CloudTranslator\src\utils\ai_image_studio.py"
            )
            $studioPy = $possibleStudios | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($pythonCmd -and $studioPy -and $isLocalFile) {
                try {
                    $outTmp = [System.IO.Path]::GetTempFileName() + ".png"
                    $pyArgs = "remove-bg --input `"$file`" --output `"$outTmp`" --mode transparent"
                    & $pythonCmd.Source $studioPy $pyArgs.Split(" ") | Out-Null
                    if (Test-Path $outTmp) {
                        $res = [pscustomobject]@{
                            status = "success"
                            downloadUrl = ""
                            id = "local"
                            tempFile = $outTmp
                        }
                    }
                } catch { }
            }
        }

        if (-not $res -or $res.status -eq "error") {
            $errDetail = if ($res -and $res.error) { $res.error } else { "No se pudo procesar la imagen con IA en este momento." }
            Write-VorkStatusLine -Kind error -Text "Error de procesamiento IA" -Detail $errDetail
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $dlUrl = if ($res.downloadUrl) {
            if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
        } else {
            "$ApiBase/api/image/download?id=$($res.id)"
        }

        Write-VorkStatusLine -Kind ok -Text "Edición IA completada con éxito"

        $outputMode = Select-VorkImageOutputAction -PromptTitle "Entrega de la imagen procesada"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Entrega cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "all")
        $hasDownload = $outputMode -in @("download", "all")

        if ($hasLocal) {
            try {
                if ($res -and $res.tempFile -and (Test-Path $res.tempFile)) {
                    Copy-Item -Path $res.tempFile -Destination $out -Force
                    try { Remove-Item -Path $res.tempFile -Force -ErrorAction SilentlyContinue } catch {}
                } elseif (-not (Test-Path $out)) {
                    Invoke-WebRequest -Uri $dlUrl -OutFile $out -UseBasicParsing -TimeoutSec 90
                }
                if (Test-Path $out) {
                    $resolvedOut = (Resolve-Path $out).Path
                    Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
                }
            } catch {
                if ($dlUrl) { Write-VorkInfoRow -Label "Descarga" -Value $dlUrl -ValueColor $Yellow }
            }
        }

        if ($hasDownload) {
            if ($dlUrl) { Write-VorkInfoRow -Label "Enlace" -Value $dlUrl -ValueColor $Cyan }
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Fondo & Edición IA" -Message "Procesamiento de imagen completado con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de procesamiento IA" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
