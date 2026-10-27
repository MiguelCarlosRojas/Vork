<#
.SYNOPSIS
    Pilar 01: Vork Traductor en la Nube (+200 idiomas por lotes)
#>

function Invoke-PillarTranslate {
    param([string[]]$ArgsList)

    $text = if ($ArgsList -and $ArgsList.Length -gt 0) { $ArgsList[0] } else { $null }
    $to = "en"
    if ($ArgsList) {
        for ($i=0; $i -lt $ArgsList.Length; $i++) {
            if ($ArgsList[$i] -in "-To", "--to", "-t") { $to = $ArgsList[$i+1] }
        }
    }

    if (-not $text) {
        Write-Host ""
        Write-Host "  ${Cyan}${Bold}╭─ [01] Vork Traductor en la Nube (+200 Idiomas)${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el texto que deseas traducir:${Reset}"
        $text = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $text -or -not $text.Trim()) {
            Write-Host "  ${Lead}╰─ Traducción cancelada.${Reset}"
            Write-Host ""
            return
        }
        $text = $text.Trim()

        $langOptions = @(
            @{ Value = "en"; Label = "[1]  en (Inglés)" },
            @{ Value = "es"; Label = "[2]  es (Español)" },
            @{ Value = "fr"; Label = "[3]  fr (Francés)" },
            @{ Value = "de"; Label = "[4]  de (Alemán)" },
            @{ Value = "it"; Label = "[5]  it (Italiano)" },
            @{ Value = "pt"; Label = "[6]  pt (Portugués)" },
            @{ Value = "ja"; Label = "[7]  ja (Japonés)" },
            @{ Value = "zh"; Label = "[8]  zh (Chino)" },
            @{ Value = "ru"; Label = "[9]  ru (Ruso)" },
            @{ Value = "ko"; Label = "[10] ko (Coreano)" }
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
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Error al traducir]:${Reset} $($_.Exception.Message)"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Wait-VorkGoBack
    Write-Host ""
}
