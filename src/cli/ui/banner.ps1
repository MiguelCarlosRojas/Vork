<#
.SYNOPSIS
    Vork CLI - Modulo UI: Banner y Tarjeta Terminal V (Adaptable a Temas y Modo Claro/Oscuro)

.DESCRIPTION
    Genera la tarjeta visual moderna de Vork CLI con insignia superior, logotipo V
    vectorial estilizado a la derecha y datos de sesión (modelo y directorio) a la
    izquierda. Se adapta automáticamente a los 10 temas visuales (/theme) y a la
    paleta claro/oscuro/sistema configurada en /config.
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
        "expert" { $Purple }
        default  { $Cyan }
    }
    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
    $versionBadge = "v$VorkVersion"

    # Logo V estilizado a escala simétrica (4 líneas, 9 columnas exactas)
    $sF = [string][char]0x2588 # █
    $sU = [string][char]0x2580 # ▀
    $vRows = @(
        (($sF * 2) + "     " + ($sF * 2)),
        ($sU + ($sF * 2) + "   " + ($sF * 2) + $sU),
        (" " + $sU + ($sF * 2) + " " + ($sF * 2) + $sU + " "),
        ("  " + $sU + ($sF * 3) + $sU + "  ")
    )

    $cH = [string][char]0x2500 # ─
    $cV = [string][char]0x2502 # │
    $cTL = [string][char]0x256D # ╭
    $cTR = [string][char]0x256E # ╮
    $cBL = [string][char]0x2570 # ╰
    $cBR = [string][char]0x256F # ╯
    $cChev = [string][char]0x276F # ❯

    Write-Host ""

    if ($width -ge 48 -and $metrics.Height -ge 8) {
        $cardW = [Math]::Min(72, [Math]::Max(46, $width - 2))
        $inner = $cardW - 2
        $rightPad = if ($cardW -ge 60) { 4 } else { 2 }
        $logoW = 9
        $logoCol = $inner - $rightPad - $logoW

        $badgeStr = "${cH}${cH}[ ${White}${Bold}VORK CLI ${Cyan}$versionBadge${Lead} ]"
        $badgeVis = 2 + 2 + 9 + 1 + $versionBadge.Length + 2
        $remH = [Math]::Max(2, $inner - $badgeVis)
        Write-Host "  ${Lead}${cTL}${badgeStr}$([string]::new($cH, $remH))${cTR}${Reset}"

        # Presupuesto horizontal seguro para no desbordar en terminales medianas
        $maxPathBudget = [Math]::Max(10, ($logoCol - 6))

        for ($i = 0; $i -lt 4; $i++) {
            $leftText = if ($i -eq 1) {
                "${White}$modelName${Reset} ${tierColor}($tierLabel)${Reset}"
            } elseif ($i -eq 2) {
                $pathShown = $currPath
                if ($pathShown.Length -gt $maxPathBudget) {
                    $pathShown = "..." + $pathShown.Substring($pathShown.Length - ($maxPathBudget - 3))
                }
                "${Coral}${cChev}${Reset} ${LeadLight}$pathShown${Reset}"
            } else {
                ""
            }

            $logoText = "${Coral}$($vRows[$i])${Reset}"
            $lVis = ($leftText -replace "\x1B\[[0-9;]*[a-zA-Z]", "").Length
            $midSpaces = [Math]::Max(1, ($logoCol - 3) - $lVis)

            Write-Host "  ${Lead}${cV}${Reset}   $leftText$([string]::new(' ', $midSpaces))$logoText$([string]::new(' ', $rightPad))${Lead}${cV}${Reset}"
        }

        Write-Host "  ${Lead}${cBL}$([string]::new($cH, $inner))${cBR}${Reset}"
    } else {
        # Cabecera compacta responsive para terminales ultra estrechas (< 48 cols)
        $badgeStr = "${cH}${cH}[ ${White}${Bold}VORK CLI ${Cyan}$versionBadge${Lead} ]"
        $cW = [Math]::Max(20, $width - 2)
        $remH = [Math]::Max(2, $cW - 2 - 16)
        Write-Host "  ${Lead}${cTL}${badgeStr}$([string]::new($cH, $remH))${cTR}${Reset}"
        Write-Host "  ${Lead}${cV}${Reset} ${White}$modelName${Reset} ${tierColor}($tierLabel)${Reset}"
        Write-Host "  ${Lead}${cV}${Reset} ${Coral}${cChev}${Reset} ${LeadLight}$currPath${Reset}"
        Write-Host "  ${Lead}${cBL}$([string]::new($cH, [Math]::Max(2, $cW - 2)))${cBR}${Reset}"
    }

    Write-Host ""
}
