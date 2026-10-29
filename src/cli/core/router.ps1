<#
.SYNOPSIS
    Vork CLI - Modulo Core: Despachador y consola interactiva REPL responsive.
#>

function Dispatch-CLICommand {
    param(
        [string]$Cmd,
        [string[]]$ArgsList
    )

    $Normalized = if ($Cmd) { $Cmd.TrimStart("/").ToLower() } else { "" }

    switch ($Normalized) {
        # ========================================================
        # CATEGORIA 1: PILARES OPERACIONALES (9)
        # ========================================================
        "translate" { Invoke-PillarTranslate -ArgsList $ArgsList }
        "tts"       { Invoke-PillarTTS -ArgsList $ArgsList }
        "clone"     { Invoke-PillarClone -ArgsList $ArgsList }
        "media"     { Invoke-PillarMedia -ArgsList $ArgsList }
        "separate"  { Invoke-PillarSeparate -ArgsList $ArgsList }
        "image"     { Invoke-PillarImage -ArgsList $ArgsList }
        "remove-bg" { Invoke-PillarRemoveBg -ArgsList $ArgsList }
        "agents"    { Invoke-PillarAgents -ArgsList $ArgsList }

        # ========================================================
        # CATEGORIA 2: AGENTES AUTONOMOS & PLANIFICACION IA (8)
        # ========================================================

        "goal"       { Invoke-CmdGoal -ArgsList $ArgsList }
        "plan"       { Invoke-CmdPlan -ArgsList $ArgsList }
        "teamwork"   { Invoke-CmdTeamwork -ArgsList $ArgsList }
        "learn"      { Invoke-CmdLearn -ArgsList $ArgsList }
        "automation" { Invoke-CmdAutomation }

        # ========================================================
        # CATEGORIA 3: CONTEXTO, SESION & MEMORIA (7)
        # ========================================================
        { $_ -in "clear", "cls" } {
            Clear-Host
            Show-Banner
        }
        "reset"   { Invoke-CmdReset }
        "history" { Invoke-CmdHistory }
        "save"    { Invoke-CmdSave -ArgsList $ArgsList }
        "resume"  { Invoke-CmdResume }
        "undo"    { Invoke-CmdUndo }

        # ========================================================
        # CATEGORIA 4: CODIGO, AUDITORIA & FLUJO (4)
        # ========================================================
        "status"   { Invoke-CmdStatus }

        # ========================================================
        # CATEGORIA 5: CONFIGURACION & PREFERENCIAS (6)
        # ========================================================
        { $_ -in "settings", "config", "permissions" } {
            [void](Show-InteractiveSettings)
            Write-Host "  ${LeadLight}Configuración cerrada.${Reset}"
            Write-Host ""
        }
        { $_ -in "mode", "modal", "model", "tier", "effort" } {
            $argVal = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
            if ($argVal -in "low", "medium", "high", "expert") {
                Set-VorkTier -NewTier $argVal
            } else {
                $modelResult = Show-InteractiveModelSwitcher
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Exited /model command${Reset}"
                Write-Host ""
            }
        }
        "theme"       { Invoke-CmdTheme -ArgsList $ArgsList }
        "env"         { Invoke-CmdEnv }

        # ========================================================
        # CATEGORIA 6: SISTEMA, TELEMETRIA & UTILIDADES (6)
        # ========================================================
        { $_ -in "help", "--help", "-h", "?", "shortcuts", "/shortcuts" } {
            if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
                Show-Help
            } else {
                $chosen = Show-InteractiveHelpModal
                if ($chosen) {
                    Dispatch-CLICommand -Cmd $chosen -ArgsList @()
                }
            }
        }
        { $_ -in "slash", "slashcommands", "commands" } {
            Show-SlashCommands
        }
        { $_ -in "update", "upgrade" } {
            Write-Host ""
            Write-Host "  $ESC[44;97;1m VORK CLI $Reset $Cyan Consultando actualizaciones en el backend ($ApiBase)...$Reset"
            Check-And-AutoUpdate -Force
            Write-Host "  $($CSI)42;30;1m OK $Reset $Green El entorno de terminal esta en su version mas reciente ($VorkVersion).$Reset"
            Write-Host ""
        }
        "health" { Invoke-CmdStatus }
        "ping" {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $online = $false
            try {
                $r = Invoke-RestMethod -Uri "$ApiBase/api/ping" -TimeoutSec 5 -ErrorAction Stop
                $sw.Stop()
                $online = $true
            } catch {
                $sw.Stop()
            }

            Write-VorkSectionHeader -Title "Latencia de red" -Subtitle "prueba de conectividad con la nube Vork" -RightText "vork · ping"
            Write-VorkInfoRow -Label "Servidor" -Value $ApiBase -ValueColor $Cyan
            if ($online) {
                $latMs = $sw.ElapsedMilliseconds
                $latColor = if ($latMs -lt 150) { $Green } elseif ($latMs -lt 400) { $Yellow } else { $Coral }
                Write-VorkInfoRow -Label "Respuesta" -Value "PONG" -ValueColor $Green
                Write-VorkInfoRow -Label "Latencia" -Value "${latMs} ms" -ValueColor $latColor
                Write-VorkSectionRule
                Write-VorkStatusLine -Kind "ok" -Text "Conexión activa y estable con la infraestructura Vork Cloud."
            } else {
                Write-VorkInfoRow -Label "Respuesta" -Value "OFFLINE / TIMEOUT" -ValueColor $Coral
                Write-VorkSectionRule
                Write-VorkStatusLine -Kind "error" -Text "No se pudo establecer conexión con el backend ($ApiBase)."
            }
            Write-Host ""
        }
        "docs" {
            Write-Host "  ${Cyan}Abriendo documentacion oficial de Vork en el navegador...${Reset}"
            Start-Process "$ApiBase/docs"
        }
        { $_ -in "version", "-v", "--version" } {
            Invoke-PillarVersion
        }
        { $_ -in "exit", "quit", "q" } {
            Exit-VorkSession -ExitCode 0
        }

        default {
            if ($Cmd.StartsWith("/")) {
                Write-Host ""
                Write-Host "  ${Coral}[!] Comando no reconocido:${Reset} $White`"$Cmd`"$Reset"
                Write-Host "  ${Dim}Escribe '?' para atajos o 'slash' para ver los 40 comandos con barra.${Reset}"
                Write-Host ""
            } else {
                $fullChat = "$Cmd $($ArgsList -join ' ')".Trim()
                Invoke-VorkAIChat -Prompt $fullChat
            }
        }
    }
}

function Get-VorkPromptTierColor {
    param([string]$Tier)

    switch (([string]$Tier).ToLower()) {
        "low"    { return $Green }
        "medium" { return $Yellow }
        "high"   { return $Coral }
        "expert" { return $Purple }
        default  { return $Cyan }
    }
}

function Format-VorkPromptStatus {
    param(
        [string]$Status,
        [int]$Width
    )

    if (-not $Status -or $Width -lt 36) { return "" }

    if ($Status -match '(?i)ctrl\s*\+\s*c') {
        $warning = if ($Width -lt 58) { "ctrl+c otra vez" } else { $Status }
        return "${Yellow}${Bold}$([char]0x26A0)${Reset} ${Yellow}$warning${Reset}"
    }

    $segments = @($Status -split ([string][char]0x00B7) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($segments.Count -ge 2) {
        $model = [string]$segments[0]
        $tier = [string]$segments[$segments.Count - 1]
        $tierLabel = if ($tier.Length -gt 1) { $tier.Substring(0, 1).ToUpper() + $tier.Substring(1).ToLower() } else { $tier.ToUpper() }
        $tierColor = Get-VorkPromptTierColor -Tier $tier

        if ($Width -lt 58) {
            return "${tierColor}$([char]0x25CF)${Reset} ${tierColor}${Bold}$tierLabel${Reset}"
        }

        return "${tierColor}$([char]0x25CF)${Reset} ${White}${Bold}$model${Reset} ${White}$([char]0x00B7)${Reset} ${tierColor}${Bold}$tierLabel${Reset}"
    }

    return "${LeadLight}$Status${Reset}"
}

function Get-VorkPromptPlaceholder {
    param([int]$Budget)

    if ($Budget -lt 8) { return "" }

    $candidates = @(
        "Escribe tu mensaje o usa /comando",
        "Mensaje o /comando",
        "Mensaje o /cmd",
        "/comando"
    )

    foreach ($candidate in $candidates) {
        if ((Get-VorkDisplayWidth $candidate) -le $Budget) { return $candidate }
    }

    return ""
}

function Get-VorkPromptHints {
    param(
        [int]$Width,
        [bool]$MenuOpen
    )

    $upDown = [string]([char]0x2191) + [string]([char]0x2193)
    $enter = [string][char]0x23CE

    if ($MenuOpen) {
        if ($Width -ge 80) {
            return @(
                @{ Key = $upDown; Label = "navegar" },
                @{ Key = "tab";    Label = "completar" },
                @{ Key = "enter";  Label = "ejecutar" },
                @{ Key = "esc";    Label = "cerrar" }
            )
        }
        if ($Width -ge 60) {
            return @(
                @{ Key = $upDown; Label = "" },
                @{ Key = "tab";    Label = "completar" },
                @{ Key = $enter;   Label = "ejecutar" },
                @{ Key = "esc";    Label = "" }
            )
        }
        return @(
            @{ Key = $upDown; Label = "" },
            @{ Key = "tab";    Label = "" },
            @{ Key = $enter;   Label = "" },
            @{ Key = "esc";    Label = "" }
        )
    }

    if ($Width -ge 50) {
        return @(
            @{ Key = "?";       Label = "for shortcuts" },
            @{ Key = "ctrl+c:"; Label = "salir" }
        )
    }
    if ($Width -ge 35) {
        return @(
            @{ Key = "?";       Label = "shortcuts" },
            @{ Key = "ctrl+c:"; Label = "salir" }
        )
    }
    return @(
        @{ Key = "?";       Label = "" },
        @{ Key = "ctrl+c:"; Label = "" }
    )
}

function Format-VorkHintLine {
    param(
        [array]$Hints,
        [int]$MaxWidth
    )

    if (-not $Hints -or $Hints.Count -eq 0 -or $MaxWidth -le 0) { return "" }

    $separator = " ${White}$([char]0x00B7)${Reset} "
    $separatorWidth = 3
    $output = ""
    $used = 0

    foreach ($hint in $Hints) {
        $key = [string]$hint.Key
        $label = [string]$hint.Label
        if (-not $key) { continue }

        $pieceWidth = Get-VorkDisplayWidth $key
        if ($label) { $pieceWidth += 1 + (Get-VorkDisplayWidth $label) }

        $needed = $pieceWidth
        if ($output) { $needed += $separatorWidth }
        if (($used + $needed) -gt $MaxWidth) { break }

        if ($output) { $output += $separator }
        $output += "${White}${Bold}$key${Reset}"
        if ($label) { $output += " ${White}$label${Reset}" }
        $used += $needed
    }

    return $output
}

function Get-VorkPromptPathLabel {
    param([int]$MaxWidth = 28)

    $path = try { (Get-Location).Path } catch { "" }
    if (-not $path) { return "" }

    $homePath = [string]$HOME
    if ($homePath -and $path.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $path.Substring($homePath.Length).TrimStart([char[]]@('\', '/'))
        $path = if ($relative) { "~/" + ($relative -replace '\\', '/') } else { "~" }
    } else {
        $path = $path -replace '\\', '/'
    }

    if ($MaxWidth -gt 2 -and (Get-VorkDisplayWidth $path) -gt $MaxWidth) {
        while ($path.Length -gt 1 -and (Get-VorkDisplayWidth $path) -gt ($MaxWidth - 1)) {
            $path = $path.Substring(1)
        }
        $path = [string][char]0x2026 + $path
    }

    return $path
}

function Format-VorkMenuItemLine {
    param(
        [string]$Cmd,
        [string]$Desc,
        [bool]$Selected,
        [int]$InnerWidth
    )

    $inner = [Math]::Max(6, $InnerWidth)
    $vertical = [char]0x2502
    $arrow = [char]0x25B8
    $showDesc = $inner -ge 32
    $cmdWidth = if ($showDesc) {
        [Math]::Max(13, [Math]::Min(18, [int][Math]::Floor($inner * 0.3)))
    } else {
        $inner - 4
    }

    $cmdText = if ((Get-VorkDisplayWidth $Cmd) -le $cmdWidth) {
        $Cmd
    } elseif ($cmdWidth -ge 2) {
        (Limit-VorkAnsiText -Text $Cmd -MaxWidth ($cmdWidth - 1) -Ellipsis "") + [string][char]0x2026
    } else {
        ""
    }
    $cmdPad = $cmdText + [string]::new(' ', [Math]::Max(0, $cmdWidth - (Get-VorkDisplayWidth $cmdText)))

    if ($showDesc) {
        $descBudget = [Math]::Max(0, $inner - $cmdWidth - 4)
        $descText = if ((Get-VorkDisplayWidth $Desc) -le $descBudget) {
            $Desc
        } elseif ($descBudget -ge 2) {
            (Limit-VorkAnsiText -Text $Desc -MaxWidth ($descBudget - 1) -Ellipsis "") + [string][char]0x2026
        } else {
            ""
        }
        $descWidth = Get-VorkDisplayWidth $descText
        $fill = [string]::new(' ', [Math]::Max(0, $inner - $cmdWidth - 4 - $descWidth))
    } else {
        $descText = ""
        $fill = [string]::new(' ', [Math]::Max(0, $inner - 3 - (Get-VorkDisplayWidth $cmdText)))
    }

    if ($Selected) {
        if ($showDesc) {
            return "  ${Lead}$vertical${Reset}${BgSel} ${Cyan}${Bold}$arrow ${White}${Bold}$cmdPad ${LeadLight}$descText$fill${Reset} ${Lead}$vertical${Reset}"
        }
        return "  ${Lead}$vertical${Reset}${BgSel} ${Cyan}${Bold}$arrow ${White}${Bold}$cmdText$fill${Reset} ${Lead}$vertical${Reset}"
    }

    if ($showDesc) {
        return "  ${Lead}$vertical${Reset}   ${White}$cmdPad${Reset} ${LeadLight}$descText$fill${Reset} ${Lead}$vertical${Reset}"
    }

    return "  ${Lead}$vertical${Reset}   ${White}$cmdText$fill${Reset} ${Lead}$vertical${Reset}"
}

function Write-VorkPromptFrame {
    param(
        [int]$PromptRow,
        [int]$Width,
        [int]$Height,
        [string]$Text,
        [int]$Cursor,
        [array]$MenuItems,
        [int]$MenuSelected,
        [int]$MenuTop,
        [int]$MenuVisible,
        [bool]$MenuOpen,
        [string]$Status,
        [int]$MenuRows,
        [int]$PreviousMenuRows = 0
    )

    $maxWidth = [Math]::Max(4, $Width - 1)
    $actualRows = if ($MenuOpen) { 3 + [Math]::Max(0, $MenuRows) } else { 3 }
    $panel = [pscustomobject]@{
        Top          = $PromptRow
        Rows         = $actualRows
        Width        = $Width
        Height       = $Height
        BufferHeight = 0
    }
    try { [Console]::CursorVisible = $false } catch { }

    # Cabecera: marca en coral + estado de modelo/tier alineado a la derecha.
    $statusText = Format-VorkPromptStatus -Status $Status -Width $Width
    $titleText = ""
    Write-VorkPanelLine -Panel $panel -Index 0 -Text (Format-VorkBorderTop -Title $titleText -RightText $statusText -Width $Width)

    # Linea de entrada con placeholder atenuado cuando el buffer esta vacio.
    $inner = [Math]::Max(1, $Width - 9)
    $view = Get-VorkTextWindow -Text $Text -Cursor $Cursor -Width $inner
    $shownText = $view.Text
    $textWidth = Get-VorkDisplayWidth $view.Text

    if (-not $Text) {
        $placeholder = Get-VorkPromptPlaceholder -Budget $inner
        if ($placeholder) {
            $shownText = "${LeadLight}$placeholder${Reset}"
            $textWidth = Get-VorkDisplayWidth $placeholder
        }
    }

    $padding = [Math]::Max(0, ($Width - 3) - (6 + $textWidth))
    $inputLine = "  ${Lead}$([char]0x2502)${Reset} ${Coral}${Bold}$([char]0x276F)${Reset} $shownText$([string]::new(' ', $padding)) ${Lead}$([char]0x2502)${Reset}"
    Write-VorkPanelLine -Panel $panel -Index 1 -Text $inputLine

    # Pie de pagina: atajos contextuales que se recortan segun el ancho disponible.
    $hints = Get-VorkPromptHints -Width $Width -MenuOpen $MenuOpen
    $leftText = Format-VorkHintLine -Hints $hints -MaxWidth ([Math]::Max(0, $maxWidth - 8))
    $rightText = ""

    if ($MenuOpen) {
        $above = $MenuTop
        $below = [Math]::Max(0, $MenuItems.Count - ($MenuTop + $MenuVisible))

        if ($Width -ge 64) {
            $scrollText = if ($below -gt 0 -and $above -gt 0) {
                "$([char]0x2191)$above $([char]0x00B7) $([char]0x2193)$below"
            } elseif ($below -gt 0) {
                "$([char]0x2193) $below"
            } elseif ($above -gt 0) {
                "$([char]0x2191) $above"
            } else {
                ""
            }

            if ($scrollText) {
                $rightText = "${Lead}$scrollText"
                $leftText = Format-VorkHintLine -Hints $hints -MaxWidth ([Math]::Max(0, $maxWidth - 12 - (Get-VorkDisplayWidth $scrollText)))
            }
        }

        Write-VorkPanelLine -Panel $panel -Index 2 -Text (Format-VorkBorderMiddle -RightText $rightText -Width $Width)

        # Lista de comandos: SOLO cuando el menu esta activo
        $menuStart = 3
        $menuInner = [Math]::Max(6, $Width - 7)

        for ($i = 0; $i -lt $MenuRows; $i++) {
            $row = $menuStart + $i
            $itemIndex = $MenuTop + $i
            if ($i -lt $MenuVisible -and $itemIndex -lt $MenuItems.Count) {
                $item = $MenuItems[$itemIndex]
                $isSelected = $itemIndex -eq $MenuSelected
                $line = Format-VorkMenuItemLine -Cmd ([string]$item.Cmd) -Desc ([string]$item.Desc) -Selected $isSelected -InnerWidth $menuInner
                Write-VorkPanelLine -Panel $panel -Index $row -Text $line
            } elseif ($i -eq $MenuVisible) {
                Write-VorkPanelLine -Panel $panel -Index $row -Text (Format-VorkBorderBottom -LeftText $leftText -Width $Width)
            } else {
                Write-VorkPanelLine -Panel $panel -Index $row -Text ""
            }
        }
    } else {
        Write-VorkPanelLine -Panel $panel -Index 2 -Text (Format-VorkBorderBottom -LeftText $leftText -RightText "" -Width $Width)

        # Limpiar filas del menu que hayan quedado de una apertura anterior
        if ($PreviousMenuRows -gt 0) {
            for ($k = 0; $k -lt $PreviousMenuRows; $k++) {
                $cleanRow = $PromptRow + 3 + $k
                try {
                    if ($cleanRow -lt [Console]::BufferHeight) {
                        [Console]::SetCursorPosition(0, $cleanRow)
                        Write-Host "$ClrLine$ClrToEnd" -NoNewline
                    }
                } catch { }
            }
        }
    }

    try {
        $cursorColumn = 6 + $view.Cursor
        if ($cursorColumn -ge ($Width - 1)) { $cursorColumn = $Width - 2 }
        if ($cursorColumn -lt 0) { $cursorColumn = 0 }
        if (($PromptRow + 1) -ge 0 -and ($PromptRow + 1) -lt [Console]::BufferHeight) {
            [Console]::SetCursorPosition($cursorColumn, $PromptRow + 1)
        }
        try { [Console]::CursorVisible = $true } catch { }
    } catch { }
}

function Read-InteractiveVorkLine {
    param(
        [string]$Status = ""
    )

    if ([Console]::IsInputRedirected) {
        return [Console]::ReadLine()
    }

    $allCommands = @(
        @{ Cmd = "/translate";   Desc = "Traduccion neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Sintesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonacion vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminacion de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestacion de subagentes en terminal interactiva" },
        @{ Cmd = "/goal";        Desc = "Modo autonomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificacion guiada y desglose paso a paso" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/automation";  Desc = "Disenar y programar tareas en segundo plano" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },
        @{ Cmd = "/status";      Desc = "Telemetria y estado operativo de los 9 pilares" },
        @{ Cmd = "/config";      Desc = "Panel interactivo de configuraciones y permisos" },
        @{ Cmd = "/model";       Desc = "Selector de modelo (Vork 3, 3.1, 3.2 Expert) y potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $buffer = [System.Text.StringBuilder]::new()
    $position = 0
    $selected = 0
    $top = 0
    $menuOpen = $false
    $filtered = @()
    $historyIndex = -1
    $draft = ""
    $navigatingHistory = $false
    $lastCtrlC = [DateTime]::MinValue
    $ctrlCWarning = $false
    $menuDismissed = $false

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::TreatControlCAsInput = $true } catch { }
    try { [Console]::CursorVisible = $true } catch { }

    try {
        $metrics = Get-VorkConsoleMetrics
        $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
        Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
        $promptRow = try { [Console]::CursorTop } catch { 0 }
        $previousMenuRows = 0

        while ($true) {
            $text = $buffer.ToString()
            $isSlash = (-not $navigatingHistory) -and (-not $menuDismissed) -and $text.StartsWith("/") -and (-not $text.Contains(" "))

            if ($isSlash) {
                $filtered = @($allCommands | Where-Object { $_.Cmd.StartsWith($text, [System.StringComparison]::OrdinalIgnoreCase) })
                if ($filtered.Count -gt 0) {
                    $menuOpen = $true
                    if ($selected -ge $filtered.Count) { $selected = 0 }
                    if ($selected -lt 0) { $selected = 0 }
                } else {
                    $menuOpen = $false
                }
            } else {
                $menuOpen = $false
                $filtered = @()
            }

            $metrics = Get-VorkConsoleMetrics
            $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
            $menuVisible = [Math]::Max(1, $menuRows - 1)
            if ($menuOpen -and $filtered.Count -gt 0) {
                if ($selected -lt $top) { $top = $selected }
                if ($selected -ge ($top + $menuVisible)) { $top = $selected - $menuVisible + 1 }
                if ($top -lt 0) { $top = 0 }
                $maxTop = [Math]::Max(0, $filtered.Count - $menuVisible)
                if ($top -gt $maxTop) { $top = $maxTop }
            } else {
                $top = 0
            }

            $statusText = $Status
            if (-not $statusText) {
                $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
                $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
                $statusText = "$modelName · $tierName"
            }
            if ($ctrlCWarning) { $statusText = "ctrl+c otra vez para salir" }


            $promptWidth = [Math]::Max(20, $metrics.Width - 1)
            Write-VorkPromptFrame -PromptRow $promptRow -Width $promptWidth -Height $metrics.Height -Text $text -Cursor $position -MenuItems $filtered -MenuSelected $selected -MenuTop $top -MenuVisible $menuVisible -MenuOpen $menuOpen -Status $statusText -MenuRows $menuRows -PreviousMenuRows $previousMenuRows
            $previousMenuRows = if ($menuOpen) { $menuRows } else { 0 }

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) {
                try {
                    [Console]::SetCursorPosition(0, $promptRow)
                    Write-Host "$ESC[0J" -NoNewline
                } catch {
                    try { Write-Host "$ESC[1A$ESC[0J" -NoNewline } catch { }
                }
                $metrics = Get-VorkConsoleMetrics
                $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
                Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
                $promptRow = try { [Console]::CursorTop } catch { 0 }
                continue
            }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) {
                $ctrlCWarning = $false
                if ($buffer.Length -gt 0) {
                    [void]$buffer.Clear()
                    $position = 0
                    $menuOpen = $false
                    $menuDismissed = $false
                    $navigatingHistory = $false
                    $historyIndex = -1
                    $lastCtrlC = [DateTime]::MinValue
                    continue
                }

                $now = [DateTime]::UtcNow
                if (($now - $lastCtrlC).TotalSeconds -lt 2.5) {
                    try { [Console]::TreatControlCAsInput = $false } catch { }
                    $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                    Clear-VorkPanel -Panel $panel
                    Exit-VorkSession -ExitCode 0
                }

                $lastCtrlC = $now
                $ctrlCWarning = $true
                continue
            }

            if ($ctrlCWarning) { $ctrlCWarning = $false }
            $lastCtrlC = [DateTime]::MinValue

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::D) -and $buffer.Length -eq 0) {
                try { [Console]::TreatControlCAsInput = $false } catch { }
                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel
                Exit-VorkSession -ExitCode 0
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::L)) {
                Clear-Host
                Show-Banner
                Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
                $promptRow = try { [Console]::CursorTop } catch { 0 }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                $finalText = if ($menuOpen -and $filtered.Count -gt 0) { [string]$filtered[$selected].Cmd } else { $buffer.ToString() }

                $rowsToClear = if ($menuOpen) { 3 + $menuRows } else { 3 }
                $panel = [pscustomobject]@{ Top = $promptRow; Rows = $rowsToClear; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel

                if ($finalText.Trim().Length -gt 0) {
                    $submitted = "  ${Coral}${Bold}$([char]0x276F)${Reset} ${White}$finalText${Reset}"
                    Write-Host (Limit-VorkAnsiText -Text $submitted -MaxWidth ([Math]::Max(10, $metrics.Width - 1)))
                    try { [Console]::SetCursorPosition(0, $promptRow + 1) } catch { }
                }

                try { [Console]::TreatControlCAsInput = $false } catch { }
                return $finalText
            }

            if ($key.Key -eq [ConsoleKey]::Tab) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $chosen = [string]$filtered[$selected].Cmd
                    [void]$buffer.Clear()
                    [void]$buffer.Append($chosen)
                    $position = $buffer.Length
                    $menuOpen = $false
                    $menuDismissed = $true
                    $navigatingHistory = $false
                    $historyIndex = -1
                    $selected = 0
                    $top = 0
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $selected = if ($selected -gt 0) { $selected - 1 } else { $filtered.Count - 1 }
                    continue
                }

                if ($global:VorkSessionHistory -and $global:VorkSessionHistory.Count -gt 0) {
                    $navigatingHistory = $true
                    if ($historyIndex -lt 0) {
                        $draft = $buffer.ToString()
                        $historyIndex = $global:VorkSessionHistory.Count - 1
                    } elseif ($historyIndex -gt 0) {
                        $historyIndex--
                    }

                    [void]$buffer.Clear()
                    [void]$buffer.Append([string]$global:VorkSessionHistory[$historyIndex])
                    $position = $buffer.Length
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($menuOpen -and $filtered.Count -gt 0) {
                    $selected = if ($selected -lt ($filtered.Count - 1)) { $selected + 1 } else { 0 }
                    continue
                }

                if ($navigatingHistory -and $historyIndex -ge 0) {
                    if ($historyIndex -lt ($global:VorkSessionHistory.Count - 1)) {
                        $historyIndex++
                        [void]$buffer.Clear()
                        [void]$buffer.Append([string]$global:VorkSessionHistory[$historyIndex])
                    } else {
                        $historyIndex = -1
                        $navigatingHistory = $false
                        [void]$buffer.Clear()
                        [void]$buffer.Append($draft)
                    }
                    $position = $buffer.Length
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                if ($menuOpen) { $menuOpen = $false; $menuDismissed = $true }
                $position = Get-VorkCursorBoundary -Text $buffer.ToString() -Position $position -Direction -1
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                if ($menuOpen) { $menuOpen = $false; $menuDismissed = $true }
                $position = Get-VorkCursorBoundary -Text $buffer.ToString() -Position $position -Direction 1
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::A))) {
                if ($menuOpen) { $menuOpen = $false; $menuDismissed = $true }
                $position = 0
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::E))) {
                if ($menuOpen) { $menuOpen = $false; $menuDismissed = $true }
                $position = $buffer.Length
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($menuOpen) {
                    $menuOpen = $false
                    $menuDismissed = $true
                    continue
                }
                if ($navigatingHistory) {
                    $navigatingHistory = $false
                    $historyIndex = -1
                    [void]$buffer.Clear()
                    [void]$buffer.Append($draft)
                    $position = $buffer.Length
                    continue
                }
                if ($buffer.Length -gt 0) {
                    [void]$buffer.Clear()
                    $position = 0
                    $menuDismissed = $false
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
                $navigatingHistory = $false
                $historyIndex = -1
                $menuDismissed = $false
                $selected = 0
                $top = 0
                if ($position -gt 0) {
                    $start = Get-VorkCursorBoundary -Text $buffer.ToString() -Position $position -Direction -1
                    [void]$buffer.Remove($start, $position - $start)
                    $position = $start
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $navigatingHistory = $false
                $historyIndex = -1
                $menuDismissed = $false
                $selected = 0
                $top = 0
                if ($position -lt $buffer.Length) {
                    $end = Get-VorkCursorBoundary -Text $buffer.ToString() -Position $position -Direction 1
                    [void]$buffer.Remove($position, $end - $position)
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                [void]$buffer.Clear()
                $position = 0
                $navigatingHistory = $false
                $historyIndex = -1
                $menuDismissed = $false
                $selected = 0
                $top = 0
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::K)) {
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, $buffer.Length - $position)
                }
                $menuDismissed = $false
                $selected = 0
                $top = 0
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::W)) {
                if ($position -gt 0) {
                    $currentText = $buffer.ToString()
                    $cut = $position
                    while ($cut -gt 0 -and [char]::IsWhiteSpace($currentText[$cut - 1])) { $cut-- }
                    while ($cut -gt 0 -and -not [char]::IsWhiteSpace($currentText[$cut - 1])) { $cut-- }
                    [void]$buffer.Remove($cut, $position - $cut)
                    $position = $cut
                }
                $menuDismissed = $false
                $selected = 0
                $top = 0
                continue
            }

            if ($buffer.Length -eq 0 -and $key.KeyChar -eq '?') {
                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
                Clear-VorkPanel -Panel $panel
                try { [Console]::TreatControlCAsInput = $false } catch { }
                return "?"
            }

            $char = $key.KeyChar
            if (-not [char]::IsControl($char)) {
                $navigatingHistory = $false
                $historyIndex = -1
                $menuDismissed = $false
                [void]$buffer.Insert($position, $char)
                $position++
                $selected = 0
                $top = 0

                # Drenar caracteres disponibles en cola (escritura rapida o pegado)
                while ($true) {
                    $hasMore = $false
                    try { $hasMore = [Console]::KeyAvailable } catch { }
                    if (-not $hasMore) { break }
                    $nextKey = [Console]::ReadKey($true)
                    $nextChar = $nextKey.KeyChar
                    if (-not [char]::IsControl($nextChar)) {
                        [void]$buffer.Insert($position, $nextChar)
                        $position++
                    } else {
                        break
                    }
                }
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursor } catch { }
    }
}

function Start-InteractiveREPL {
    Set-VorkWindowIdentity
    if ($global:VorkIsResumed) {
        Load-VorkConversationState -ConvId $global:VorkConversationId
    }
    Clear-Host
    Show-Banner

    if ($global:VorkIsResumed) {
        Show-ResumedConversationTranscript -ConvId $global:VorkConversationId
    }

    $elbow = [char]0x23BF

    while ($true) {
        $line = Read-InteractiveVorkLine
        if ($null -eq $line) {
            Exit-VorkSession -ExitCode 0
        }

        $line = $line.Trim()
        if (-not $line) { continue }

        if (-not $global:VorkSessionHistory) { $global:VorkSessionHistory = [System.Collections.ArrayList]@() }
        if ($line -and ($global:VorkSessionHistory.Count -eq 0 -or $global:VorkSessionHistory[$global:VorkSessionHistory.Count - 1] -ne $line)) {
            [void]$global:VorkSessionHistory.Add($line)
            try {
                $historyDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $historyDir)) { New-Item -ItemType Directory -Path $historyDir -Force | Out-Null }
                Add-Content -Path (Join-Path $historyDir "history.txt") -Value $line -Encoding UTF8
            } catch { }
        }

        # ATAJOS DIRECTOS: Si el usuario pulsa '?' o escribe /help, /shortcuts, /?: abrir modal de atajos
        if ($line -eq "?" -or $line -in @("/help", "/shortcuts", "/?")) {
            $modalChosen = Show-InteractiveHelpModal
            Clear-Host
            Show-Banner
            if ($modalChosen) {
                Dispatch-CLICommand -Cmd $modalChosen -ArgsList @()
            }
            continue
        }

        # REGLA ESTRICTA: Cualquier texto que NO inicie con '/' se procesa directamente con Vork AI Chat
        if (-not $line.StartsWith("/")) {
            Invoke-VorkAIChat -Prompt $line
            continue
        }

        # Procesamiento exclusivo de comandos con barra ('/')
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errors)

        $cleanTokens = @($tokens | Where-Object { $_.Kind.ToString() -notin @("EndOfInput", "NewLine") })
        if ($cleanTokens.Count -eq 0) { continue }

        $replCmd = $cleanTokens[0].Text.Trim('"', "'")
        $replArgs = @()
        if ($cleanTokens.Count -gt 1) {
            for ($k = 1; $k -lt $cleanTokens.Count; $k++) {
                $replArgs += $cleanTokens[$k].Text.Trim('"', "'")
            }
        }

        $cmdCheck = $replCmd.TrimStart("/").ToLower()

        if ($cmdCheck -in "exit", "quit", "q") {
            Exit-VorkSession -ExitCode 0
        }

        if ($cmdCheck -in "clear", "cls") {
            Clear-Host
            Show-Banner
            continue
        }

        if ($cmdCheck -in "help", "?", "shortcuts") {
            $modalChosen = Show-InteractiveHelpModal
            Clear-Host
            Show-Banner
            if ($modalChosen) {
                Dispatch-CLICommand -Cmd $modalChosen -ArgsList @()
            }
            continue
        }

        if ($cmdCheck -in "mode", "modal", "model", "tier", "effort") {
            $argVal = if ($replArgs -and $replArgs.Count -gt 0) { $replArgs[0].ToLower() } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
                $outMsg = "Set effort to $argVal"
                Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                Write-Host ""
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            } else {
                $modelResult = Show-InteractiveModelSwitcher
                $outMsg = "Exited /model command"
                Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                Write-Host ""
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            }
            continue
        }

        if ($cmdCheck -eq "theme") {
            Invoke-CmdTheme -ArgsList $replArgs
            $outMsg = if ($replArgs -and $replArgs.Count -gt 0) { "Changed theme to $global:VorkThemeName" } else { "Exited /theme command" }
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        if ($cmdCheck -in "config", "settings", "permissions") {
            $settingsResult = Show-InteractiveSettings
            $outMsg = "Exited /config command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        Dispatch-CLICommand -Cmd $replCmd -ArgsList $replArgs
        if ($replCmd.StartsWith("/")) {
            $outMsg = "Exited $replCmd command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Write-Host ""
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            Send-VorkNotification -Title "Vork CLI" -Message "Comando $replCmd ejecutado con éxito."
        }
    }
}

# ========================================================
# CONTROL DE ENTRADA: INTERACTIVO vs COMANDO DIRECTO
# ========================================================
Check-And-AutoUpdate

if (-not $Command -or $Command.ToLower() -in "tui", "interactive") {
    Start-InteractiveREPL
} else {
    Dispatch-CLICommand -Cmd $Command -ArgsList $Arguments
    $fullCmd = "$Command $($Arguments -join ' ')".Trim()
    $outMsg = if ($Command.StartsWith("/")) { "Exited $Command command" } else { "Executed $Command" }
    Save-VorkConversationRecord -Cmd $fullCmd -Output $outMsg
}
