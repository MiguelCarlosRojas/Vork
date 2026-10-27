<#
.SYNOPSIS
    Vork CLI - Modulo Core: Despachador y Consola Interactiva REPL
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
        # CATEGORIA 2: AGENTES AUTÓNOMOS & PLANIFICACIÓN IA (8)
        # ========================================================
        "goal"       { Invoke-CmdGoal -ArgsList $ArgsList }
        "plan"       { Invoke-CmdPlan -ArgsList $ArgsList }
        "grill-me"   { Invoke-CmdGrillMe }
        "teamwork"   { Invoke-CmdTeamwork -ArgsList $ArgsList }
        "boost"      { Invoke-CmdBoost }
        "learn"      { Invoke-CmdLearn -ArgsList $ArgsList }
        "browser"    { Invoke-CmdBrowser -ArgsList $ArgsList }
        "automation" { Invoke-CmdAutomation }

        # ========================================================
        # CATEGORIA 3: CONTEXTO, SESIÓN & MEMORIA (7)
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
        # CATEGORIA 4: CÓDIGO, AUDITORÍA & FLUJO (4)
        # ========================================================
        "status"   { Invoke-CmdStatus }
        "review"   { Invoke-CmdReview }
        "bug"      { Invoke-CmdBug -ArgsList $ArgsList }
        "refactor" { Invoke-CmdRefactor }

        # ========================================================
        # CATEGORIA 5: CONFIGURACIÓN & PREFERENCIAS (6)
        # ========================================================
        { $_ -in "settings", "config", "permissions" } { Show-InteractiveSettings }
        "keybindings" { Invoke-CmdKeybindings }
        { $_ -in "mode", "modal", "model", "tier", "effort" } {
            $argVal = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
            if ($argVal -in "low", "medium", "high") {
                Set-VorkTier -NewTier $argVal
            } else {
                Show-InteractiveModelSwitcher
            }
        }
        "theme"       { Invoke-CmdTheme -ArgsList $ArgsList }
        "env"         { Invoke-CmdEnv }

        # ========================================================
        # CATEGORIA 6: SISTEMA, TELEMETRÍA & UTILIDADES (6)
        # ========================================================
        { $_ -in "help", "--help", "-h", "?", "shortcuts", "/shortcuts" } {
            $chosen = Show-InteractiveHelpModal
            if ($chosen) {
                Dispatch-CLICommand -Cmd $chosen -ArgsList @()
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
            Write-Host ""
            Write-Host "  ${Coral}[!] Comando no reconocido:${Reset} $White`"$Cmd`"$Reset"
            Write-Host "  ${Dim}Escribe '?' para atajos o 'slash' para ver los 40 comandos con barra.${Reset}"
            Write-Host ""
        }
    }
}

function Read-InteractiveVorkLine {
    param(
        [int]$PromptRow,
        [int]$Width,
        [string]$Rule,
        [string]$Footer
    )

    if ([Console]::IsInputRedirected) {
        return [Console]::ReadLine()
    }

    $allCommands = @(
        # Categoria 1: Pilares (9)
        @{ Cmd = "/translate";   Desc = "Traduccion neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Sintesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonacion vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminacion de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestacion de subagentes en terminal interactiva" },

        # Categoria 2: Agentes & Planificacion (8)
        @{ Cmd = "/goal";        Desc = "Modo autonomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificacion guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseño" },
        @{ Cmd = "/teamwork";    Desc = "Coordinacion con multiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificacion estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegacion e interaccion web automatizada" },
        @{ Cmd = "/automation";  Desc = "Diseñar y programar tareas en segundo plano" },

        # Categoria 3: Sesion & Memoria (7)
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesion" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesion a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronologico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesion, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesion previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la ultima accion o cambio de codigo" },

        # Categoria 4: Flujo de Trabajo & Auditoría (4)
        @{ Cmd = "/status";      Desc = "Inspeccionar estado del entorno y tareas activas" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },

        # Categoria 5: Configuracion & Preferencias (6)
        @{ Cmd = "/settings";    Desc = "Panel interactivo de configuraciones y permisos del sistema" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },

        # Categoria 6: Sistema, Telemetria & Utilidades (6)
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $buf = [System.Text.StringBuilder]::new()
    $selIdx = 0
    $topIdx = 0
    $slashMenuOpen = $false
    $windowSize = 5
    $menuHeight = 7

    try { [Console]::TreatControlCAsInput = $true } catch { }
    $lastCtrlC = [DateTime]::MinValue

    $downArrow = [char]0x2193
    $upArrow   = [char]0x2191
    $dotCh     = [char]0x00B7

    $clearMenu = {
        for ($r = 0; $r -le 10; $r++) {
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 3 + $r)
                Write-Host "$ClrLine" -NoNewline
            } catch { }
        }
        try {
            [Console]::SetCursorPosition(0, $PromptRow + 2)
            Write-Host "${LeadLight}$Footer${Reset}$ClrToEnd" -NoNewline
        } catch { }
    }

    $histIdx = -1
    $savedDraft = ""
    $isNavigatingHistory = $false
    $filtered = @()

    while ($true) {
        $str = $buf.ToString()
        $isSlash = (-not $isNavigatingHistory) -and $str.StartsWith("/") -and (-not $str.Contains(" "))

        if ($isSlash) {
            $filtered = @($allCommands | Where-Object { $_.Cmd.StartsWith($str, [System.StringComparison]::OrdinalIgnoreCase) })
            if ($filtered.Count -gt 0) {
                if ($selIdx -ge $filtered.Count) { $selIdx = 0 }

                # Adjust scrolling window
                if ($selIdx -lt $topIdx) {
                    $topIdx = $selIdx
                } elseif ($selIdx -ge ($topIdx + $windowSize)) {
                    $topIdx = $selIdx - $windowSize + 1
                }
                if ($topIdx -gt ($filtered.Count - $windowSize) -and ($filtered.Count -gt $windowSize)) {
                    $topIdx = $filtered.Count - $windowSize
                }
                if ($topIdx -lt 0) { $topIdx = 0 }

                $slashMenuOpen = $true

                # Render the 5 visible items
                for ($k = 0; $k -lt $windowSize; $k++) {
                    $itemIdx = $topIdx + $k
                    $rowY = $PromptRow + 3 + $k
                    try { [Console]::SetCursorPosition(0, $rowY) } catch { }

                    if ($itemIdx -lt $filtered.Count) {
                        $item = $filtered[$itemIdx]
                        $cmdStr = $item.Cmd.PadRight(18)
                        $descStr = $item.Desc
                        $availDesc = [Math]::Max(10, ($Width - 1) - 22)
                        if ($descStr.Length -gt $availDesc) {
                            $descStr = $descStr.Substring(0, $availDesc - 3) + "..."
                        }

                        if ($itemIdx -eq $selIdx) {
                            Write-Host "${Cyan}${Bold}> ${White}${Bold}$cmdStr${LeadLight}$descStr${Reset}$ClrToEnd" -NoNewline
                        } else {
                            Write-Host "  ${White}$cmdStr${LeadLight}$descStr${Reset}$ClrToEnd" -NoNewline
                        }
                    } else {
                        Write-Host "$ClrLine" -NoNewline
                    }
                }

                # Row 6: More indicator
                $remBelow = $filtered.Count - ($topIdx + $windowSize)
                $remAbove = $topIdx
                $moreText = ""
                if ($remBelow -gt 0 -and $remAbove -gt 0) {
                    $moreText = "   $upArrow $remAbove / $downArrow $remBelow more"
                } elseif ($remBelow -gt 0) {
                    $moreText = "   $downArrow $remBelow more"
                } elseif ($remAbove -gt 0) {
                    $moreText = "   $upArrow $remAbove more"
                }
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 3 + $windowSize)
                    Write-Host "${LeadDark}$moreText${Reset}$ClrToEnd" -NoNewline
                } catch { }

                # Row 7: Navigation hints
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 3 + $windowSize + 1)
                    Write-Host "  ${Cyan}$upArrow/$downArrow${Reset} ${LeadLight}Navigate ${LeadDark}$dotCh${Reset} ${Cyan}enter${Reset} ${LeadLight}Select ${LeadDark}$dotCh${Reset} ${Cyan}tab${Reset} ${LeadLight}Complete ${LeadDark}$dotCh${Reset} ${Cyan}esc${Reset} ${LeadLight}Cancel${Reset}$ClrToEnd" -NoNewline
                } catch { }

                # Reposition cursor cleanly on prompt row
                try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
            } else {
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                    try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                }
            }
        } else {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
                try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
            }
        }

        $key = [Console]::ReadKey($true)

        # Intercepción de Ctrl+C (Evita mensaje "¿Desea terminar el trabajo por lotes (S/N)?" y ofrece doble confirmación)
        $isCtrlC = ($key.KeyChar -eq [char]3) -or ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control))
        if ($isCtrlC) {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            if ($buf.Length -gt 0) {
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2, $PromptRow)
                } catch { }
                $buf.Clear() | Out-Null
                $lastCtrlC = [DateTime]::MinValue
                continue
            }

            # Buffer vacío: comprobar doble pulsación
            $now = [DateTime]::UtcNow
            if (($now - $lastCtrlC).TotalSeconds -lt 2.5) {
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                    Write-Host ([string]::new(" ", [Math]::Min(80, $Width - 1))) -NoNewline
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                } catch { }
                try { [Console]::TreatControlCAsInput = $false } catch { }
                Exit-VorkSession -ExitCode 0
            } else {
                $lastCtrlC = $now
                try {
                    [Console]::SetCursorPosition(0, $PromptRow + 2)
                    $warnMsg = "press ctrl+c again to exit"
                    $dotCh = [char]0x00B7
                    $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
                    $tierColor = switch ($tierName) {
                        "low"    { $Green }
                        "medium" { $Yellow }
                        "high"   { $Coral }
                        default  { $Cyan }
                    }
                    $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
                    $rightPlain = "$modelName $dotCh $tierName"
                    $rightFormatted = "${LeadLight}$modelName $dotCh $tierName${Reset}"
                    $padLen = [Math]::Max(1, ($Width - 1) - $warnMsg.Length - $rightPlain.Length)
                    Write-Host "${LeadLight}$warnMsg$([string]::new(' ', $padLen))$rightFormatted" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        # Restaurar footer si estaba visible el aviso de ctrl+c y se pulsó otra tecla
        if ($lastCtrlC -ne [DateTime]::MinValue) {
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 2)
                Write-Host "${LeadLight}$Footer${Reset}" -NoNewline
                [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
            } catch { }
            $lastCtrlC = [DateTime]::MinValue
        }

        # Intercepción de Ctrl+D
        $isCtrlD = ($key.KeyChar -eq [char]4) -or ($key.Key -eq [ConsoleKey]::D -and ($key.Modifiers -band [ConsoleModifiers]::Control))
        if ($isCtrlD -and $buf.Length -eq 0) {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            Exit-VorkSession -ExitCode 0
        }

        if ($key.Key -eq [ConsoleKey]::Enter) {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $chosen = $filtered[$selIdx].Cmd
                & $clearMenu
                $slashMenuOpen = $false
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$chosen${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(0, $PromptRow + 3)
                } catch { }
                Write-Host ""
                return $chosen
            }

            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            $finalText = $buf.ToString()
            try {
                [Console]::SetCursorPosition(2, $PromptRow)
                Write-Host "${Coral}${Bold}$finalText${Reset}$ClrToEnd" -NoNewline
                [Console]::SetCursorPosition(0, $PromptRow + 3)
            } catch { }
            Write-Host ""
            return $finalText
        }

        if ($key.Key -eq [ConsoleKey]::Tab) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $chosen = $filtered[$selIdx].Cmd
                & $clearMenu
                $slashMenuOpen = $false
                $isNavigatingHistory = $false
                $histIdx = -1
                $buf.Clear() | Out-Null
                $buf.Append($chosen) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$chosen${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $selIdx = if ($selIdx -gt 0) { $selIdx - 1 } else { $filtered.Count - 1 }
                continue
            } elseif ($global:VorkSessionHistory -and $global:VorkSessionHistory.Count -gt 0) {
                $isNavigatingHistory = $true
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                }
                if ($histIdx -lt 0) {
                    $savedDraft = $buf.ToString()
                    $histIdx = $global:VorkSessionHistory.Count - 1
                } elseif ($histIdx -gt 0) {
                    $histIdx--
                }

                $chosenHist = $global:VorkSessionHistory[$histIdx]
                $buf.Clear() | Out-Null
                $buf.Append($chosenHist) | Out-Null

                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            if ($slashMenuOpen -and $filtered.Count -gt 0) {
                $selIdx = if ($selIdx -lt ($filtered.Count - 1)) { $selIdx + 1 } else { 0 }
                continue
            } elseif ($isNavigatingHistory -and $histIdx -ge 0) {
                if ($slashMenuOpen) {
                    & $clearMenu
                    $slashMenuOpen = $false
                }
                if ($histIdx -lt ($global:VorkSessionHistory.Count - 1)) {
                    $histIdx++
                    $chosenHist = $global:VorkSessionHistory[$histIdx]
                    $buf.Clear() | Out-Null
                    $buf.Append($chosenHist) | Out-Null
                } else {
                    $histIdx = -1
                    $isNavigatingHistory = $false
                    $buf.Clear() | Out-Null
                    $buf.Append($savedDraft) | Out-Null
                }

                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
        }

        if ($key.Key -eq [ConsoleKey]::Escape) {
            if ($slashMenuOpen) {
                & $clearMenu
                $slashMenuOpen = $false
            }
            if ($isNavigatingHistory) {
                $isNavigatingHistory = $false
                $histIdx = -1
                $buf.Clear() | Out-Null
                $buf.Append($savedDraft) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                continue
            }
            if ($buf.Length -gt 0) {
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "$ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2, $PromptRow)
                } catch { }
                $buf.Clear() | Out-Null
            }
            try {
                [Console]::SetCursorPosition(0, $PromptRow + 2)
                Write-Host "${LeadLight}$Footer${Reset}" -NoNewline
                [Console]::SetCursorPosition(2, $PromptRow)
            } catch { }
            $lastCtrlC = [DateTime]::MinValue
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Backspace -or $key.KeyChar -eq [char]8) {
            $isNavigatingHistory = $false
            $histIdx = -1
            if ($buf.Length -gt 0) {
                $buf.Remove($buf.Length - 1, 1) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset} $ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                if ($buf.Length -eq 0 -or -not $buf.ToString().StartsWith("/") -or $buf.ToString().Contains(" ")) {
                    if ($slashMenuOpen) {
                        & $clearMenu
                        $slashMenuOpen = $false
                        try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                    }
                }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Delete) {
            $isNavigatingHistory = $false
            $histIdx = -1
            if ($buf.Length -gt 0) {
                $buf.Remove($buf.Length - 1, 1) | Out-Null
                try {
                    [Console]::SetCursorPosition(2, $PromptRow)
                    Write-Host "${Coral}${Bold}$($buf.ToString())${Reset} $ClrToEnd" -NoNewline
                    [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
                } catch { }
                if ($buf.Length -eq 0 -or -not $buf.ToString().StartsWith("/") -or $buf.ToString().Contains(" ")) {
                    if ($slashMenuOpen) {
                        & $clearMenu
                        $slashMenuOpen = $false
                        try { [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow) } catch { }
                    }
                }
            }
            continue
        }

        if ($buf.Length -eq 0 -and $key.KeyChar -eq '?') {
            try { [Console]::TreatControlCAsInput = $false } catch { }
            return "?"
        }

        $ch = $key.KeyChar
        if (-not [char]::IsControl($ch)) {
            $isNavigatingHistory = $false
            $histIdx = -1
            $buf.Append($ch) | Out-Null
            try {
                [Console]::SetCursorPosition(2, $PromptRow)
                Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
                [Console]::SetCursorPosition(2 + $buf.Length, $PromptRow)
            } catch {
                Write-Host "${Coral}${Bold}$($buf.ToString())${Reset}$ClrToEnd" -NoNewline
            }
            $selIdx = 0
            $topIdx = 0
        }
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

    $lineChar = [char]0x2500
    $dotChar = [char]0x00B7

    while ($true) {
        $width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
        if ($width -le 20 -or $width -gt 300) { $width = 120 }
        $rule = [string]::new($lineChar, ($width - 1))

        # Asegurar buffer vertical suficiente y espacio visible debajo
        try {
            if ([Console]::BufferHeight -lt 1000) {
                [Console]::BufferHeight = 1000
            }
        } catch { }

        $neededLines = 14
        try {
            $currY = [Console]::CursorTop
            $winBottom = [Console]::WindowTop + [Console]::WindowHeight
            if (($winBottom - $currY) -lt $neededLines) {
                $scrollNeeded = $neededLines - ($winBottom - $currY)
                for ($s = 0; $s -lt $scrollNeeded; $s++) {
                    [Console]::WriteLine()
                }
                [Console]::SetCursorPosition(0, [Console]::CursorTop - $scrollNeeded)
            }
        } catch { }

        $left = "? for shortcuts"
        $tierName = if ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
        $tierColor = switch ($tierName) {
            "low"    { $Green }
            "medium" { $Yellow }
            "high"   { $Coral }
            default  { $Cyan }
        }
        $modelName = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3" }
        $rightPlain = "$modelName " + $dotChar + " " + $tierName
        $rightFormatted = "${LeadLight}$modelName " + $dotChar + " $tierName${Reset}"
        $padLen = [Math]::Max(1, ($width - 1) - $left.Length - $rightPlain.Length)
        $footer = "${LeadLight}$left" + (" " * $padLen) + $rightFormatted

        Write-Host "${Lead}$rule${Reset}"
        Write-Host "${Coral}${Bold}> ${Reset}"
        Write-Host "${Lead}$rule${Reset}"
        Write-Host "$footer" -NoNewline

        # Calcular $pRow exactamente 2 filas arriba de la línea de pie de página
        $pRow = try { [Console]::CursorTop - 2 } catch { 0 }
        try { [Console]::SetCursorPosition(2, $pRow) } catch { Write-Host "$ESC[2A$ESC[2G" -NoNewline }

        $line = Read-InteractiveVorkLine -PromptRow $pRow -Width $width -Rule $rule -Footer $footer
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
                $hDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $hDir)) { New-Item -ItemType Directory -Path $hDir -Force | Out-Null }
                Add-Content -Path (Join-Path $hDir "history.txt") -Value $line -Encoding UTF8
            } catch { }
        }

        $tokens = $null
        $errs = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errs)

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
        $elbow = [char]0x23BF

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
                Save-VorkConversationRecord -Cmd $line -Output $outMsg
            } else {
                $mRes = Show-InteractiveModelSwitcher
                if ($mRes -and $mRes.Action -eq "selected") {
                    $outMsg = "Switched to $($mRes.Model) · $($mRes.Tier)"
                    Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                    Save-VorkConversationRecord -Cmd $line -Output $outMsg
                } else {
                    $outMsg = "Exited /model command"
                    Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
                    Save-VorkConversationRecord -Cmd $line -Output $outMsg
                }
            }
            continue
        }

        if ($cmdCheck -eq "theme") {
            Invoke-CmdTheme -ArgsList $replArgs
            $outMsg = if ($replArgs -and $replArgs.Count -gt 0) { "Changed theme to $global:VorkThemeName" } else { "Exited /theme command" }
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        if ($cmdCheck -in "permissions", "settings", "config") {
            $sRes = Show-InteractiveSettings
            $outMsg = "Exited /settings command"
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
            Save-VorkConversationRecord -Cmd $line -Output $outMsg
            continue
        }

        Dispatch-CLICommand -Cmd $replCmd -ArgsList $replArgs
        $outMsg = if ($replCmd.StartsWith("/")) { "Exited $replCmd command" } else { "Executed $replCmd" }
        if ($replCmd.StartsWith("/")) {
            Write-Host "  ${LeadLight}$elbow  $outMsg${Reset}"
        }
        Save-VorkConversationRecord -Cmd $line -Output $outMsg
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
