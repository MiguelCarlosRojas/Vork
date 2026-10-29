<#
.SYNOPSIS
    Pilar 10: Vork Generador de Imágenes IA (FLUX.1 Neural · 100% Gratuito y Sin Marca de Agua)
#>

function Invoke-PillarGenerateImage {
    param([string[]]$ArgsList)

    $prompt = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList -join " " } else { $null }
    $ratio = "1:1"
    $width = 1024
    $height = 1024
    $out = $null

    if (-not $prompt) {
        Write-VorkSectionHeader -Title "Generación de imagen con IA" -Subtitle "FLUX.1 Neural · 1024x1024 sin marca de agua" -RightText "vork · imagen ia"
        Write-Host "    ${LeadLight}Describe en detalle lo que deseas ver en la imagen:${Reset}"
        $pInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $pInput -or -not $pInput.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Generación cancelada."
            Write-Host ""
            return
        }
        $prompt = $pInput.Trim()

        $ratioOptions = @(
            @{ Value = "1:1";  Label = "1:1 Cuadrado";    Description = "1024 x 1024 · Ideal para avatares, arte y redes" },
            @{ Value = "16:9"; Label = "16:9 Panorámico"; Description = "1024 x 576 · Fondos de pantalla, cine y web" },
            @{ Value = "9:16"; Label = "9:16 Vertical";   Description = "576 x 1024 · Stories, TikTok, Reels y móviles" },
            @{ Value = "4:3";  Label = "4:3 Fotografía";  Description = "1024 x 768 · Proporción clásica fotográfica" }
        )

        $chosenRatio = Select-InteractiveOption -PromptTitle "Proporción y tamaño" -Subtitle "resolución FLUX.1" -Options $ratioOptions -DefaultIndex 0
        if ($chosenRatio) {
            $ratio = $chosenRatio
            switch ($ratio) {
                "1:1"  { $width = 1024; $height = 1024 }
                "16:9" { $width = 1024; $height = 576 }
                "9:16" { $width = 576;  $height = 1024 }
                "4:3"  { $width = 1024; $height = 768 }
            }
        }
    }

    $outName = "imagen_ia_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".jpg"
    $out = if ($out) { $out } else { $outName }

    Write-VorkSectionHeader -Title "Procesando imagen IA" -RightText "vork · imagen ia"
    Write-VorkInfoRow -Label "Prompt" -Value "`"$prompt`"" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Motor" -Value "FLUX.1-schnell (Black Forest Labs · Sin marca de agua)" -ValueColor $Green
    Write-VorkInfoRow -Label "Tamaño" -Value "${width}x${height} (${ratio})" -ValueColor $Yellow
    Write-VorkSectionRule

    $body = @{
        prompt = $prompt
        width = $width
        height = $height
        seed = (Get-Random -Minimum 1 -Maximum 999999)
    } | ConvertTo-Json

    $endpoint = "$ApiBase/api/image/generate"

    try {
        try { Add-Type -AssemblyName System.Net.Http } catch { }

        $res = $null
        $barLen = 22
        $pRow = -1
        try {
            Write-Host "    ${LeadLight}Progreso${Reset} [${Gray}$([string]::new([char]0x2591, $barLen))${Reset}]   0%  ${LeadLight}Conectando con FLUX.1 Neural...${Reset}"
            $pRow = [Console]::CursorTop - 1
        } catch { }

        if ('System.Net.Http.HttpClient' -as [type]) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromMinutes(4)
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

                $phase = if ($pct -lt 25) {
                    "Traduciendo y optimizando prompt..."
                } elseif ($pct -lt 55) {
                    "Muestreando espacio latente con FLUX.1..."
                } elseif ($pct -lt 85) {
                    "Decodificando VAE en alta resolución..."
                } else {
                    "Finalizando renderizado sin marca de agua..."
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
            $res = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 240
        }

        # Fallback local con Gradio Client directo si el backend en Render tarda
        if (-not $res -or $res.status -eq "error") {
            $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
            if ($nodeCmd) {
                try {
                    $jsonPrompt = $prompt | ConvertTo-Json
                    $jsCode = 'const { generateImageFromPrompt } = require("./src/utils/imageEngine"); generateImageFromPrompt({ prompt: ' + $jsonPrompt + ', width: ' + $width + ', height: ' + $height + ' }).then(r => console.log(JSON.stringify(r))).catch(e => console.error(JSON.stringify({ status: "error", error: e.message })));'
                    $localOut = & $nodeCmd.Source -e $jsCode 2>&1
                    $parsed = ($localOut | Out-String).Trim() | ConvertFrom-Json
                    if ($parsed -and $parsed.status -eq "success") {
                        $res = $parsed
                    }
                } catch { }
            }
        }

        if (-not $res -or $res.status -eq "error") {
            $errDetail = if ($res -and $res.error) { $res.error } else { "No se pudo generar la imagen con el modelo FLUX.1 en este momento." }
            Write-VorkStatusLine -Kind error -Text "Error de generación IA" -Detail $errDetail
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $dlUrl = if ($res.downloadUrl) {
            if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
        } else {
            "$ApiBase/api/image/download?id=$($res.id)"
        }

        Write-VorkStatusLine -Kind ok -Text "Imagen neuronal generada con éxito"

        $outputMode = Select-VorkImageOutputAction -PromptTitle "Entrega de la imagen generada"
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
                if ($res.imageBase64) {
                    $rawB64 = $res.imageBase64 -replace '^data:image/[^;]+;base64,', ''
                    [System.IO.File]::WriteAllBytes((Join-Path (Get-Location) $out), [System.Convert]::FromBase64String($rawB64))
                } elseif ($dlUrl) {
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
        Send-VorkNotification -Title "Vork Generador IA" -Message "Imagen generada con FLUX.1 con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error de generación IA" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
