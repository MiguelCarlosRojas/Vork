<#
.SYNOPSIS
    Vork CLI - Modulo UI: Banner y Logo Terminal V (Plomo Oscuro & Coral)

.DESCRIPTION
    Conserva el logo solido en bloque "V" y la cabecera clasica de Vork CLI,
    pero calcula el ancho real de la terminal para recortar de forma segura
    (sin romper colores ANSI) y cambia a una cabecera compacta cuando la
    ventana es demasiado estrecha o baja.
#>

function Show-Banner {
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)

    $currPath = try { (Get-Location).Path.Replace($HOME, "~").Replace("\", "/") } catch { "~" }
    $tierLabel = if ($global:VorkTier) { $global:VorkTier.Substring(0,1).ToUpper() + $global:VorkTier.Substring(1).ToLower() } else { "Medium" }
    $tierColor = switch ($tierLabel.ToLower()) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        default  { $Cyan }
    }
    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
    $endpointInfo = "$ApiBase (Vork AI)"
    $versionBadge = "v$VorkVersion"

    # Logo V moderno solido de 15 columnas (identico al diseno original)
    $sF = [string][char]0x2588 # █
    $v1 = "  " + ($sF * 2) + "       " + ($sF * 2) + "  "
    $v2 = "  " + ($sF * 3) + "     " + ($sF * 3) + "  "
    $v3 = "   " + ($sF * 3) + "   " + ($sF * 3) + "   "
    $v4 = "    " + ($sF * 3) + " " + ($sF * 3) + "    "
    $v5 = "     " + ($sF * 5) + "     "

    Write-Host ""

    if ($width -ge 58 -and $metrics.Height -ge 12) {
        # Cabecera completa: logo a la izquierda, datos de sesion alineados a la derecha.
        $lines = @(
            "${Coral}${v1}${Reset}    ${Coral}${Bold}Vork CLI${Reset} ${BgSel}${Cyan}${Bold} $versionBadge ${Reset}",
            "${Coral}${v2}${Reset}    ${LeadLight}$modelName ($tierLabel)${Reset}",
            "${Coral}${v3}${Reset}    ${LeadLight}$endpointInfo${Reset}",
            "${Coral}${v4}${Reset}    ${Lead}$currPath${Reset}",
            "${Coral}${v5}${Reset}"
        )

        foreach ($line in $lines) {
            Write-Host (Limit-VorkAnsiText -Text $line -MaxWidth $width)
        }
    } else {
        # Cabecera compacta para terminales estrechas o de poca altura.
        $title = "  ${Coral}${Bold}Vork CLI${Reset}  ${BgSel}${Cyan}${Bold} $versionBadge ${Reset}"
        $engine = "  ${LeadLight}$modelName${Reset} ${Lead}·${Reset} ${tierColor}${Bold}$tierLabel${Reset} ${Lead}·${Reset} ${LeadLight}$endpointInfo${Reset}"
        $path = "  ${Lead}$currPath${Reset}"

        Write-Host (Limit-VorkAnsiText -Text $title -MaxWidth $width)
        Write-Host (Limit-VorkAnsiText -Text $engine -MaxWidth $width)
        Write-Host (Limit-VorkAnsiText -Text $path -MaxWidth $width)
    }

    Write-Host ""
}
