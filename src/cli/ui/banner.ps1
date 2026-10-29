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

    $devIdentity = if ($global:VorkDeviceName) { $global:VorkDeviceName } else { (Get-VorkDeviceIdentity) }
    $userMachineLabel = "$devIdentity (Vork AI)"

    # Logo V estilizado a escala simétrica (4 líneas, 9 columnas exactas)
    $sF = [string][char]0x2588 # █
    $sU = [string][char]0x2580 # ▀
    $vRows = @(
        (($sF * 2) + "     " + ($sF * 2)),
        ($sU + ($sF * 2) + "   " + ($sF * 2) + $sU),
        (" " + $sU + ($sF * 2) + " " + ($sF * 2) + $sU + " "),
        ("  " + $sU + ($sF * 3) + $sU + "  ")
    )
    $cChev = [string][char]0x276F # ❯

    Write-Host ""

    if ($width -ge 46) {
        $vis0 = ("VORK CLI $versionBadge").Length
        $vis1 = ("$modelName ($tierLabel)").Length
        $vis2 = $userMachineLabel.Length

        # Calcular columna de anclaje para que el logo nunca se solape con el nombre de la PC ni del modelo
        $maxLeftNeeded = [Math]::Max([Math]::Max($vis0, $vis1), $vis2) + 2
        $targetLogoCol = [Math]::Min([Math]::Max(20, $width - 11), [Math]::Max(50, $maxLeftNeeded))

        # Fila 0: VORK CLI vX.X.X  |  Logo Fila 0
        $left0 = "${White}${Bold}VORK CLI${Reset} ${White}$versionBadge${Reset}"
        $pad0 = [Math]::Max(2, $targetLogoCol - $vis0)
        Write-Host "  $left0$([string]::new(' ', $pad0))${Coral}$($vRows[0])${Reset}"

        # Fila 1: Vork 3.2 (Tier)  |  Logo Fila 1
        $left1 = "${White}${Bold}$modelName${Reset} ${tierColor}($tierLabel)${Reset}"
        $pad1 = [Math]::Max(2, $targetLogoCol - $vis1)
        Write-Host "  $left1$([string]::new(' ', $pad1))${Coral}$($vRows[1])${Reset}"

        # Fila 2: <DeviceModel> (Vork AI)  |  Logo Fila 2
        $devShown = $devIdentity
        $maxDevBudget = [Math]::Max(10, $targetLogoCol - 12)
        if ($devShown.Length -gt $maxDevBudget) {
            $devShown = $devShown.Substring(0, $maxDevBudget - 3) + "..."
        }
        $left2 = "${White}$devShown${Reset} ${Cyan}(Vork AI)${Reset}"
        $vis2Shown = ("$devShown (Vork AI)").Length
        $pad2 = [Math]::Max(2, $targetLogoCol - $vis2Shown)
        Write-Host "  $left2$([string]::new(' ', $pad2))${Coral}$($vRows[2])${Reset}"

        # Fila 3: ❯ ~/Path  |  Logo Fila 3
        $maxPathBudget = [Math]::Max(10, $targetLogoCol - 5)
        $pathShown = $currPath
        if ($pathShown.Length -gt $maxPathBudget) {
            $pathShown = "..." + $pathShown.Substring($pathShown.Length - ($maxPathBudget - 3))
        }
        $left3 = "${Coral}${cChev}${Reset} ${White}$pathShown${Reset}"
        $vis3 = 2 + $pathShown.Length
        $pad3 = [Math]::Max(2, $targetLogoCol - $vis3)
        Write-Host "  $left3$([string]::new(' ', $pad3))${Coral}$($vRows[3])${Reset}"
    } else {
        # Vista compacta para terminales estrechas
        Write-Host "  ${White}${Bold}VORK CLI${Reset} ${White}$versionBadge${Reset}"
        Write-Host "  ${White}${Bold}$modelName${Reset} ${tierColor}($tierLabel)${Reset}"
        Write-Host "  ${White}$devIdentity${Reset} ${Cyan}(Vork AI)${Reset}"
        Write-Host "  ${Coral}${cChev}${Reset} ${White}$currPath${Reset}"
    }

    Write-Host ""
}
