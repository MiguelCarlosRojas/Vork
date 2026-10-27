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
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [01] Vork Traductor en la Nube (+200 Idiomas)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto que deseas traducir:${Reset}"
        $textInput = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $textInput -or -not $textInput.Trim()) {
            Write-Host "  ${Lead}╰─ Traducción cancelada.${Reset}"
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

        $chosenLang = Select-InteractiveOption -PromptTitle "Selecciona el idioma destino:" -Options $langOptions -DefaultIndex 0
        if ($chosenLang) {
            $to = $chosenLang
        }
    }

    Write-Host ""
    Write-Host "  $Cyan╭─ [01] VORK TRANSLATOR ────────────────────────────$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Destino:$Reset  $Yellow$to$Reset"
    Write-Host "  $Cyan│$Reset  $Gray Entrada:$Reset  $White`"$text`"$Reset"
    Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
    
    $body = @{ text = $text; targetLanguage = $to } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/translate" -Method Post -Body $body -ContentType "application/json"
        Write-Host "  $Cyan│$Reset  $Green✓ Traducción:$Reset $White$($res.translatedText)$Reset"
        
        $outFile = "traduccion.txt"
        [System.IO.File]::WriteAllText((Join-Path (Get-Location) $outFile), $res.translatedText, [System.Text.Encoding]::UTF8)
        $resolvedOut = (Resolve-Path $outFile).Path
        Write-Host "  $Cyan│$Reset  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error al traducir]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
