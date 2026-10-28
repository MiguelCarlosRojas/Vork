<#
.SYNOPSIS
    Pilar 01: Vork Traductor Neuronal en la Nube (+200 Idiomas)
#>

function Invoke-PillarTranslate {
    param([string[]]$ArgsList)

    $to = "en"
    $text = ""

    if ($ArgsList -and $ArgsList.Length -gt 0) {
        $to = $ArgsList[0]
        if ($ArgsList.Length -gt 1) {
            $text = ($ArgsList[1..($ArgsList.Length - 1)]) -join " "
        }
    }

    if (-not $text) {
        Write-VorkSectionHeader -Title "Traducción" -Subtitle "Texto a traducir · más de 200 idiomas" -RightText "vork · translate"
        $textInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $textInput -or -not $textInput.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Traducción cancelada."
            Write-Host ""
            return
        }
        $text = $textInput.Trim()

        $langOptions = @(
            @{ Value = "en"; Label = "en (Inglés)" },
            @{ Value = "es"; Label = "es (Español)" },
            @{ Value = "fr"; Label = "fr (Francés)" },
            @{ Value = "de"; Label = "de (Alemán)" },
            @{ Value = "it"; Label = "it (Italiano)" },
            @{ Value = "pt"; Label = "pt (Portugués)" },
            @{ Value = "ja"; Label = "ja (Japonés)" },
            @{ Value = "zh"; Label = "zh (Chino)" },
            @{ Value = "ru"; Label = "ru (Ruso)" },
            @{ Value = "ko"; Label = "ko (Coreano)" }
        )

        $chosenLang = Select-InteractiveOption -PromptTitle "Idioma destino" -Subtitle "traducción neuronal" -Options $langOptions -DefaultIndex 0
        if (-not $chosenLang) {
            Write-VorkStatusLine -Kind warn -Text "Traducción cancelada."
            Write-Host ""
            return
        }
        $to = $chosenLang
    }

    Write-VorkSectionHeader -Title "Procesando traducción" -RightText "vork · translate"
    Write-VorkInfoRow -Label "Destino" -Value $to -ValueColor $Yellow
    Write-VorkInfoRow -Label "Entrada" -Value "`"$text`""
    Write-VorkSectionRule

    $body = @{ text = $text; targetLanguage = $to } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/translate" -Method Post -Body $body -ContentType "application/json"
        Write-VorkStatusLine -Kind ok -Text "Traducción completada"
        Write-VorkInfoRow -Label "Salida" -Value $res.translatedText -ValueColor $White

        $outFile = "traduccion.txt"
        $resolvedOut = Join-Path (Get-Location) $outFile
        $dlUrl = if ($res.downloadUrl) {
            if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
        } else {
            "$ApiBase/api/translate/download?translatedText=$([System.Uri]::EscapeDataString($res.translatedText))"
        }

        $outputMode = Select-VorkTextOutputAction -PromptTitle "Entrega del texto"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Entrega cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "all")
        $hasDownload = $outputMode -in @("download", "all")

        if ($hasLocal) {
            [System.IO.File]::WriteAllText($resolvedOut, $res.translatedText, [System.Text.Encoding]::UTF8)
            $resolvedPath = (Resolve-Path $outFile).Path
            Write-VorkInfoRow -Label "Guardado" -Value $resolvedPath -ValueColor $Green
        }

        if ($hasDownload) {
            Write-VorkInfoRow -Label "Enlace" -Value $dlUrl -ValueColor $Cyan
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Traductor" -Message "Traducción completada con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error al traducir" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
