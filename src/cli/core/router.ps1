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
        { $_ -in "chat", "ai", "ask" } {
            $chatPrompt = if ($ArgsList) { $ArgsList -join " " } else { "" }
            Invoke-VorkAIChat -Prompt $chatPrompt
        }
        "goal"       { Invoke-CmdGoal -ArgsList $ArgsList }
        "plan"       { Invoke-CmdPlan -ArgsList $ArgsList }
        "grill-me"   { Invoke-CmdGrillMe }
        "teamwork"   { Invoke-CmdTeamwork -ArgsList $ArgsList }
        "boost"      { Invoke-CmdBoost }
        "learn"      { Invoke-CmdLearn -ArgsList $ArgsList }
        "browser"    { Invoke-CmdBrowser -ArgsList $ArgsList }
        "automation" { Invoke-CmdAutomation }

        # ========================================================
        # CATEGORIA 3: CONTEXTO, SESION & MEMORIA (7)
        # ========================================================
        "compact" { Invoke-CmdCompact }
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
        "review"   { Invoke-CmdReview }
        "bug"      { Invoke-CmdBug -ArgsList $ArgsList }
        "refactor" { Invoke-CmdRefactor }

        # ========================================================
        # CATEGORIA 5: CONFIGURACION & PREFERENCIAS (6)
        # ========================================================
        { $_ -in "settings", "config", "permissions" } {
            [void](Show-InteractiveSettings)
            Write-Host "  ${LeadLight}Configuración cerrada.${Reset}"
            Write-Host ""
        }
        "keybindings" { Invoke-CmdKeybindings }
        { $_ -in "mode", "modal", "model", "tier", "effort" } {
            $argVal = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
            } else {
                $modelResult = Show-InteractiveModelSwitcher
                if ($modelResult -and $modelResult.Action -eq "selected") {
                    Write-Host "  ${LeadLight}Modelo: $($modelResult.Model) · $($modelResult.Tier)${Reset}"
                } else {
                    Write-Host "  ${LeadLight}Selector de modelo cerrado.${Reset}"
                }
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
        "health" { Invoke-PillarHealth }
        "ping" {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $r = Invoke-RestMethod -Uri "$ApiBase/api/ping" -TimeoutSec 3 -ErrorAction Stop
                $sw.Stop()
                Write-Host "  ${Green}● PONG${Reset} ${White}$($sw.ElapsedMilliseconds)ms${Reset} hacia $ApiBase"
            } catch {
                Write-Host "  ${Coral}[Error Ping]:${Reset} No se pudo conectar con $ApiBase"
            }
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

        return "${tierColor}$([char]0x25CF)${Reset} ${LeadLight}$model${Reset} ${Lead}$([char]0x00B7)${Reset} ${tierColor}${Bold}$tierLabel${Reset}"
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

    if ($Width -ge 88) {
        return @(
            @{ Key = "?";      Label = "atajos" },
            @{ Key = "/";      Label = "comandos" },
            @{ Key = "ctrl+l"; Label = "limpiar" },
            @{ Key = "ctrl+c"; Label = "salir" }
        )
    }
    if ($Width -ge 64) {
        return @(
            @{ Key = "?";      Label = "atajos" },
            @{ Key = "/";      Label = "comandos" },
            @{ Key = "ctrl+c"; Label = "salir" }
        )
    }
    if ($Width -ge 46) {
        return @(
            @{ Key = "?";  Label = "ayuda" },
            @{ Key = "/";  Label = "cmds" },
            @{ Key = "^C"; Label = "salir" }
        )
    }
    return @(
        @{ Key = "?";  Label = "" },
        @{ Key = "/";  Label = "" },
        @{ Key = "^C"; Label = "" }
    )
}

function Format-VorkHintLine {
    param(
        [array]$Hints,
        [int]$MaxWidth
    )

    if (-not $Hints -or $Hints.Count -eq 0 -or $MaxWidth -le 0) { return "" }

    $separator = " ${Lead}$([char]0x00B7)${Reset} "
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
        if ($label) { $output += " ${LeadLight}$label${Reset}" }
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
        [int]$MenuRows
    )

    $maxWidth = [Math]::Max(4, $Width - 1)
    $panel = [pscustomobject]@{
        Top          = $PromptRow
        Rows         = 3 + [Math]::Max(0, $MenuRows)
        Width        = $Width
        Height       = $Height
        BufferHeight = 0
    }

    # Cabecera: marca en coral + estado de modelo/tier alineado a la derecha.
    $statusText = Format-VorkPromptStatus -Status $Status -Width $Width
    $titleText = "${Coral}${Bold}Vork CLI${Reset}"
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
    } else {
        if ($Width -ge 90) {
            $remaining = $maxWidth - 8 - (Get-VorkDisplayWidth $leftText) - 4
            if ($remaining -ge 12) {
                $pathLabel = Get-VorkPromptPathLabel -MaxWidth ([Math]::Min(28, $remaining))
                if ($pathLabel) { $rightText = "${Lead}$pathLabel" }
            }
        }

        Write-VorkPanelLine -Panel $panel -Index 2 -Text (Format-VorkBorderBottom -LeftText $leftText -RightText $rightText -Width $Width)
    }

    # Lista de comandos: fila seleccionada con fondo solido y borde derecho continuo.
    $menuStart = 3
    $menuInner = [Math]::Max(6, $Width - 7)

    for ($i = 0; $i -lt $MenuRows; $i++) {
        $row = $menuStart + $i
        $itemIndex = $MenuTop + $i
        if ($MenuOpen -and $i -lt $MenuVisible -and $itemIndex -lt $MenuItems.Count) {
            $item = $MenuItems[$itemIndex]
            $isSelected = $itemIndex -eq $MenuSelected
            $line = Format-VorkMenuItemLine -Cmd ([string]$item.Cmd) -Desc ([string]$item.Desc) -Selected $isSelected -InnerWidth $menuInner
            Write-VorkPanelLine -Panel $panel -Index $row -Text $line
        } elseif ($MenuOpen -and $i -eq $MenuVisible) {
            Write-VorkPanelLine -Panel $panel -Index $row -Text (Format-VorkBorderBottom -LeftText $leftText -Width $Width)
        } else {
            Write-VorkPanelLine -Panel $panel -Index $row -Text ""
        }
    }

    try {
        $cursorColumn = 6 + $view.Cursor
        if ($cursorColumn -ge ($Width - 1)) { $cursorColumn = $Width - 2 }
        if ($cursorColumn -lt 0) { $cursorColumn = 0 }
        [Console]::SetCursorPosition($cursorColumn, $PromptRow + 1)
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
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseno" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificacion estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegacion e interaccion web automatizada" },
        @{ Cmd = "/automation";  Desc = "Disenar y programar tareas en segundo plano" },
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },
        @{ Cmd = "/status";      Desc = "Inspeccionar estado del entorno y tareas activas" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },
        @{ Cmd = "/settings";    Desc = "Panel interactivo de configuraciones y permisos" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/chat";        Desc = "Conversar directamente con Vork AI (3.0, 3.1 o 3.2 Expert)" },
        @{ Cmd = "/model";       Desc = "Selector de modelo (Vork 3, 3.1, 3.2 Expert) y potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
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

    $savedCursor = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::TreatControlCAsInput = $true } catch { }
    try { [Console]::CursorVisible = $true } catch { }

    try {
        $metrics = Get-VorkConsoleMetrics
        $menuRows = [Math]::Max(2, [Math]::Min(8, $metrics.Height - 7))
        Ensure-VorkRowsBelow -Rows (3 + $menuRows) | Out-Null
        $promptRow = try { [Console]::CursorTop } catch { 0 }

        while ($true) {
            $text = $buffer.ToString()
            $isSlash = (-not $navigatingHistory) -and $text.StartsWith("/") -and (-not $text.Contains(" "))

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

            Write-VorkPromptFrame -PromptRow $promptRow -Width $metrics.Width -Height $metrics.Height -Text $text -Cursor $position -MenuItems $filtered -MenuSelected $selected -MenuTop $top -MenuVisible $menuVisible -MenuOpen $menuOpen -Status $statusText -MenuRows $menuRows

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

                $panel = [pscustomobject]@{ Top = $promptRow; Rows = 3 + $menuRows; Width = $metrics.Width; Height = $metrics.Height; BufferHeight = 0 }
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
                if ($position -gt 0) { $position-- }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::RightArrow) {
                if ($position -lt $buffer.Length) { $position++ }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::A))) {
                $position = 0
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End -or (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::E))) {
                $position = $buffer.Length
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($menuOpen) {
                    $menuOpen = $false
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
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
                $navigatingHistory = $false
                $historyIndex = -1
                if ($position -gt 0) {
                    [void]$buffer.Remove($position - 1, 1)
                    $position--
                }
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $navigatingHistory = $false
                $historyIndex = -1
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, 1)
                }
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::U)) {
                [void]$buffer.Clear()
                $position = 0
                $navigatingHistory = $false
                $historyIndex = -1
                continue
            }

            if (Test-VorkCtrlKey -Key $key -Letter ([ConsoleKey]::K)) {
                if ($position -lt $buffer.Length) {
                    [void]$buffer.Remove($position, $buffer.Length - $position)
                }
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
                [void]$buffer.Insert($position, $char)
                $position++
                $selected = 0
                $top = 0
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

        if ($line -eq "?") {
            $modalChosen = Show-InteractiveHelpModal
            Clear-Host
            Show-Banner
            if ($modalChosen) {
                Dispatch-CLICommand -Cmd $modalChosen -ArgsList @()
            }
            continue
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

        if ($cmdCheck -in "?", "shortcuts") {
            Show-Shortcuts
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

        if ($cmdCheck -in "permissions", "settings", "config") {
            $settingsResult = Show-InteractiveSettings
            $outMsg = "Exited /settings command"
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
