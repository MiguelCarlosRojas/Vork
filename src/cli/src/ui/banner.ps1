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
    $activeInfo = if (Get-Command "Get-VorkActiveModelInfo" -ErrorAction SilentlyContinue) { Get-VorkActiveModelInfo } else { $null }
    $modelName = if ($activeInfo) { $activeInfo.Name } elseif ($global:VorkModel) { $global:VorkModel } else { "Auto (Rotación Inteligente)" }
    $isVork = if ($activeInfo) { $activeInfo.IsVork } else { ($modelName -like "Vork*") }

    $powerTag = ""
    $tierColor = $Cyan

    if ($activeInfo -and $activeInfo.Id -eq "auto") {
        $modelName = "Auto (Rotación Inteligente)"
        $powerTag = ""
        $tierColor = $Green
    } elseif ($isVork) {
        $tierLabel = if ($modelName -like "*3.2*") { "Expert" } elseif ($global:VorkTier) { $global:VorkTier.Substring(0,1).ToUpper() + $global:VorkTier.Substring(1).ToLower() } else { "Medium" }
        if ($modelName -match '\((Expert|Low|Medium|High)\)') {
            $powerTag = ""
        } else {
            $powerTag = "($tierLabel)"
        }
        $tierColor = switch ($tierLabel.ToLower()) {
            "low"    { $Green }
            "medium" { $Yellow }
            "high"   { $Coral }
            "expert" { $Purple }
            default  { $Cyan }
        }
    } elseif ($activeInfo -and $activeInfo.Power) {
        $powerTag = "($($activeInfo.Power))"
        $tierColor = $Cyan
    } else {
        $powerTag = ""
    }

    $line1Visual = if ($powerTag) { "$modelName $powerTag" } else { "$modelName" }
    $left1 = if ($powerTag) { "${White}${Bold}$modelName${Reset} ${tierColor}$powerTag${Reset}" } else { "${White}${Bold}$modelName${Reset}" }

    $versionBadge = "v$VorkVersion"

    $devIdentity = if ($global:VorkDeviceName) { $global:VorkDeviceName } else { (Get-VorkDeviceIdentity) }
    $maxDevBudget = [Math]::Max(12, [Math]::Min(28, $width - 25))
    if ($devIdentity.Length -gt $maxDevBudget) {
        $devIdentity = $devIdentity.Substring(0, $maxDevBudget - 3) + "..."
    }
    $userMachineLabel = "$devIdentity (Vork AI)"

    # Truncamiento inteligente de la ruta para que el logo se mantenga compacto
    # Si la ruta tiene 3 o más niveles y es larga, se compacta con ~../<carpeta>/<carpeta>
    $pathShown = $currPath
    $maxPathBudget = [Math]::Max(20, [Math]::Min(38, $width - 22))
    if ($pathShown.Length -gt $maxPathBudget) {
        if ($pathShown.StartsWith("~/")) {
            $inner = $pathShown.Substring(2)
            $parts = $inner.Split('/')
            if ($parts.Length -ge 3) {
                $pathShown = "~../" + $parts[$parts.Length - 2] + "/" + $parts[$parts.Length - 1]
            } elseif ($parts.Length -eq 2) {
                $pathShown = "~../" + $parts[1]
            }
        }
        if ($pathShown.Length -gt $maxPathBudget) {
            $pathShown = "..." + $pathShown.Substring($pathShown.Length - ($maxPathBudget - 3))
        }
    }

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
        $vis1 = $line1Visual.Length
        $vis2 = $userMachineLabel.Length
        $vis3 = 2 + $pathShown.Length

        # Calcular columna de anclaje para que el logo esté justo al lado del texto
        # sin espacio innecesario, adaptándose al ancho del nombre de PC y la ubicación
        $maxLeftNeeded = [Math]::Max([Math]::Max([Math]::Max($vis0, $vis1), $vis2), $vis3)
        $targetLogoCol = [Math]::Min([Math]::Max(18, $width - 11), $maxLeftNeeded + 3)

        # Fila 0: VORK CLI vX.X.X  |  Logo Fila 0
        $left0 = "${White}${Bold}VORK CLI${Reset} ${White}$versionBadge${Reset}"
        $pad0 = [Math]::Max(2, $targetLogoCol - $vis0)
        Write-Host "  $left0$([string]::new(' ', $pad0))${Coral}$($vRows[0])${Reset}"

        # Fila 1: Modelo Activo  |  Logo Fila 1
        $pad1 = [Math]::Max(2, $targetLogoCol - $vis1)
        Write-Host "  $left1$([string]::new(' ', $pad1))${Coral}$($vRows[1])${Reset}"

        # Fila 2: <DeviceModel> (Vork AI)  |  Logo Fila 2
        $left2 = "${White}$devIdentity${Reset} ${Cyan}(Vork AI)${Reset}"
        $pad2 = [Math]::Max(2, $targetLogoCol - $vis2)
        Write-Host "  $left2$([string]::new(' ', $pad2))${Coral}$($vRows[2])${Reset}"

        # Fila 3: ❯ ~/Path  |  Logo Fila 3
        $left3 = "${Coral}${cChev}${Reset} ${White}$pathShown${Reset}"
        $pad3 = [Math]::Max(2, $targetLogoCol - $vis3)
        Write-Host "  $left3$([string]::new(' ', $pad3))${Coral}$($vRows[3])${Reset}"
    } else {
        # Vista compacta para terminales estrechas
        Write-Host "  ${White}${Bold}VORK CLI${Reset} ${White}$versionBadge${Reset}"
        Write-Host "  $left1"
        Write-Host "  ${White}$devIdentity${Reset} ${Cyan}(Vork AI)${Reset}"
        Write-Host "  ${Coral}${cChev}${Reset} ${White}$pathShown${Reset}"
    }

    Write-Host ""
}
