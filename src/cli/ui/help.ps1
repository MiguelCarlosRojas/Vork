<#
.SYNOPSIS
    Vork CLI - Modulo UI: Catalogo visual, atajos y navegador de ayuda responsive.
#>

function Write-VorkHelpLine {
    param(
        [string]$Text,
        [int]$Width = 0
    )

    if ($Width -le 0) {
        $metrics = Get-VorkConsoleMetrics
        $Width = [Math]::Max(10, $metrics.Width - 1)
    }
    Write-Host (Limit-VorkAnsiText -Text $Text -MaxWidth $Width)
}

function Show-Shortcuts {
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)

    $items = @(
        @{ Key = "/slash";       Desc = "Ver los 40 comandos con barra (/)" },
        @{ Key = "/model";       Desc = "Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)" },
        @{ Key = "/help";        Desc = "Ver catalogo detallado de los 9 pilares" },
        @{ Key = "/clear, cls";  Desc = "Limpiar pantalla y refrescar banner" },
        @{ Key = "/exit, quit, q"; Desc = "Salir de la sesion interactiva" },
        @{ Key = "/ping, /health"; Desc = "Comprobar conexion con el backend ($ApiBase)" },
        @{ Key = "/update";      Desc = "Actualizar Vork CLI al instante" }
    )

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}VORK CLI · ATAJOS & COMANDOS RAPIDOS${Reset}"

    $keyWidth = 18
    foreach ($item in $items) {
        $key = $item.Key.PadRight($keyWidth)
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}  $key${Reset}${Dim}$($item.Desc)${Reset}"
    }

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "  ${Dim}Pilares directos: translate, tts, clone, media, separate, image, remove-bg, agents${Reset}"
    Write-Host ""
}

function Show-Help {
    Show-Banner
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)
    $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 4))

    Write-VorkHelpLine -Width $width -Text "$White$Bold  SINTAXIS:$Reset"
    Write-VorkHelpLine -Width $width -Text "    $Yellow$Bold vork$Reset $Cyan<comando>$Reset $White [argumentos]$Reset   ${Dim}(Alias: vk, vork-cli, ct)${Reset}"
    Write-Host ""

    Write-VorkHelpLine -Width $width -Text "$White$Bold  LOS 9 PILARES OPERACIONALES:$Reset"

    $pillars = @(
        @{
            Title = "[01] Vork Traductor en la Nube"
            Tag = "+200 idiomas por lotes"
            Usage = "vork translate <texto> -To <iso>"
            Example = "vork translate 'Hola mundo' -To en"
        },
        @{
            Title = "[02] Vork Texto a Voz Neuronal (TTS)"
            Tag = "24 voces humanas"
            Usage = "vork tts <texto> -Voice <id> -Out <archivo>"
            Example = "vork tts 'Bienvenido a Vork' -Voice es-ES-AlvaroNeural -Out voz.mp3"
        },
        @{
            Title = "[03] Vork Clonacion de Voz IA"
            Tag = "Modelado timbrico F0"
            Usage = "vork clone -Audio <muestra> -Text <guion>"
            Example = "vork clone -Audio muestra.wav -Text 'Texto sintetizado'"
        },
        @{
            Title = "[04] Vork Conversor Multimedia"
            Tag = "YouTube, TikTok, IG a MP3/MP4"
            Usage = "vork media <url> -Format <mp3|mp4> -Quality 320"
            Example = "vork media 'https://youtube.com/watch?v=...' -Format mp3"
        },
        @{
            Title = "[05] Vork Separador de Stems"
            Tag = "Acapella / Karaoke con Demucs v4"
            Usage = "vork separate <url_o_archivo>"
            Example = "vork separate cancion.mp3"
        },
        @{
            Title = "[07] Vork Conversor de Imagenes"
            Tag = "PNG, JPG, WEBP, ICO, AVIF"
            Usage = "vork image <archivo> -Format <formato>"
            Example = "vork image logo.png -Format webp -Quality 90"
        },
        @{
            Title = "[08] Vork Estudio de Fondo IA"
            Tag = "U2-Net silueta y transparente"
            Usage = "vork remove-bg <archivo> -Out <archivo.png>"
            Example = "vork remove-bg foto.jpg -Out limpia.png"
        },
        @{
            Title = "[09] Vork Agentes Autonomos & TUI"
            Tag = "Modo orquestador de terminal"
            Usage = "vork agents / vork tui"
            Example = "vk  (alias ultracorto para ejecutar Vork CLI)"
        }
    )

    foreach ($pillar in $pillars) {
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x256D)$([char]0x2500) ${Bold}$($pillar.Title)${Reset} ${Dim}· $($pillar.Tag)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Yellow}$($pillar.Usage)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Dim}Ej: $($pillar.Example)${Reset}"
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2570)$rule${Reset}"
    }

    Write-Host ""
    Write-VorkHelpLine -Width $width -Text "$White$Bold  MANTENIMIENTO & ESTADO:$Reset"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork update$Reset     ${Dim}Sincroniza y actualiza Vork CLI al instante${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork health$Reset     ${Dim}Comprueba la telemetria y estado de los 9 pilares${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork version$Reset    ${Dim}Muestra detalles de arquitectura y version${Reset}"
    Write-VorkHelpLine -Width $width -Text "    $Yellow vork slash$Reset      ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host ""
}

function Show-SlashCommands {
    Show-Banner
    $metrics = Get-VorkConsoleMetrics
    $width = [Math]::Max(20, $metrics.Width - 1)
    $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 4))

    Write-VorkHelpLine -Width $width -Text "$White$Bold  CATALOGO COMPLETO DE LOS 40 COMANDOS CON BARRA (/):$Reset"
    Write-VorkHelpLine -Width $width -Text "  ${Dim}Uso: vork /<comando> o en la consola interactiva TUI${Reset}"
    Write-Host ""

    $categories = @(
        @{
            Title = "[CATEGORIA 1] Los 9 Pilares Operacionales (9)"
            Items = @(
                @{ Cmd = "/translate"; Desc = "Traduccion neuronal por lotes en +200 idiomas" },
                @{ Cmd = "/tts";       Desc = "Sintesis de voz con 24 voces neuronales humanas" },
                @{ Cmd = "/clone";     Desc = "Clonacion vocal IA y modelado espectral F0" },
                @{ Cmd = "/media";     Desc = "Conversion multimedia YouTube, TikTok, IG a MP3/MP4" },
                @{ Cmd = "/separate";  Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
                @{ Cmd = "/image";     Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
                @{ Cmd = "/remove-bg"; Desc = "Silueta inteligente y eliminacion de fondo IA" },
                @{ Cmd = "/agents";    Desc = "Orquestacion de subagentes en terminal interactiva" }
            )
        },
        @{
            Title = "[CATEGORIA 2] Agentes Autonomos & Planificacion IA (8)"
            Items = @(
                @{ Cmd = "/goal";       Desc = "Modo autonomo continuo para tareas exhaustivas" },
                @{ Cmd = "/plan";       Desc = "Planificacion guiada y desglose paso a paso" },
                @{ Cmd = "/grill-me";   Desc = "Entrevista interactiva para decisiones de diseno" },
                @{ Cmd = "/teamwork";   Desc = "Coordinacion con multiples subagentes concurrentes" },
                @{ Cmd = "/boost";      Desc = "Razonamiento profundo con verificacion estricta" },
                @{ Cmd = "/learn";      Desc = "Persistir reglas, correcciones y preferencias" },
                @{ Cmd = "/browser";    Desc = "Navegacion e interaccion web automatizada" },
                @{ Cmd = "/automation"; Desc = "Disenar y programar tareas en segundo plano" }
            )
        },
        @{
            Title = "[CATEGORIA 3] Contexto, Sesion & Memoria (7)"
            Items = @(
                @{ Cmd = "/compact"; Desc = "Compactar historial para liberar ventana de contexto" },
                @{ Cmd = "/clear";   Desc = "Limpiar pantalla de terminal conservando la sesion" },
                @{ Cmd = "/reset";   Desc = "Reiniciar variables y contexto de la sesion a cero" },
                @{ Cmd = "/history"; Desc = "Explorar historial cronologico de comandos ejecutados" },
                @{ Cmd = "/save";    Desc = "Guardar estado de sesion, artefactos y contexto" },
                @{ Cmd = "/resume";  Desc = "Reanudar una sesion previa o restaurar estado" },
                @{ Cmd = "/undo";    Desc = "Deshacer la ultima accion o cambio de codigo" }
            )
        },
        @{
            Title = "[CATEGORIA 4] Codigo, Auditoria & Flujo de Trabajo (4)"
            Items = @(
                @{ Cmd = "/status";   Desc = "Inspeccionar estado del entorno, archivos y tareas activas" },
                @{ Cmd = "/review";   Desc = "Auditoria de codigo, buenas practicas y seguridad" },
                @{ Cmd = "/bug";      Desc = "Diagnostico y depuracion asistida de excepciones" },
                @{ Cmd = "/refactor"; Desc = "Reestructurar y optimizar codigo sin alterar salida" }
            )
        },
        @{
            Title = "[CATEGORIA 5] Configuracion & Preferencias (6)"
            Items = @(
                @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
                @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
                @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
                @{ Cmd = "/model";       Desc = "Cambiar modelo IA y nivel de esfuerzo" },
                @{ Cmd = "/theme";       Desc = "Alternar temas visuales (Dark, Cyberpunk, Coral)" },
                @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" }
            )
        },
        @{
            Title = "[CATEGORIA 6] Sistema, Telemetria & Utilidades (6)"
            Items = @(
                @{ Cmd = "/help";   Desc = "Manual interactivo de comandos y atajos de teclado" },
                @{ Cmd = "/update"; Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
                @{ Cmd = "/health"; Desc = "Telemetria en tiempo real de los 9 pilares" },
                @{ Cmd = "/ping";   Desc = "Prueba de latencia ultrarrrapida hacia la nube" },
                @{ Cmd = "/docs";   Desc = "Abrir la documentacion oficial de Vork en el navegador" },
                @{ Cmd = "/exit";   Desc = "Cerrar la sesion de terminal de forma segura" }
            )
        }
    )

    $cmdWidth = 14
    foreach ($category in $categories) {
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x256D)$([char]0x2500) ${Bold}$($category.Title)${Reset}"
        foreach ($item in $category.Items) {
            $cmd = $item.Cmd.PadRight($cmdWidth)
            Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2502)${Reset}  ${Yellow}$cmd${Reset} ${White}· $($item.Desc)${Reset}"
        }
        Write-VorkHelpLine -Width $width -Text "  ${Cyan}$([char]0x2570)$rule${Reset}"
    }
    Write-Host ""
}

# ========================================================
# NAVEGADOR DE AYUDA INTERACTIVO (?) (MODAL MULTIPESTAÑA VORK)
# ========================================================

function Show-InteractiveHelpModal {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $null }

    $tabs = @("general", "commands", "shortcuts")
    $curTab = 0
    $cmdIdx = 0
    $scIdx = 0
    $cmdTop = 0
    $scTop = 0

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
        @{ Cmd = "/status";      Desc = "Telemetria y estado operativo en vivo de los 9 pilares" },
        @{ Cmd = "/review";      Desc = "Auditoria de codigo, buenas practicas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnostico y depuracion asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar codigo sin alterar salida" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar entre los 10 temas visuales oficiales" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la ultima version" },
        @{ Cmd = "/health";      Desc = "Telemetria en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrrapida hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentacion oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesion de terminal de forma segura" }
    )

    $shortcuts = @(
        @{ Key = "/";                      Desc = "Abrir selector interactivo de comandos con barra" },
        @{ Key = "?";                      Desc = "Abrir este navegador de ayuda interactivo" },
        @{ Key = "enter";                  Desc = "Enviar mensaje o confirmar seleccion" },
        @{ Key = "tab";                    Desc = "Autocompletar comando o ciclar pestanas" },
        @{ Key = "esc, ctrl+c";            Desc = "Volver atras / descartar menu / cancelar" },
        @{ Key = "ctrl+l";                 Desc = "Limpiar pantalla de la terminal" },
        @{ Key = "ctrl+d";                 Desc = "Salir del CLI de forma segura" },
        @{ Key = "up / down";              Desc = "Navegar historial de comandos o menus" },
        @{ Key = "left / right";           Desc = "Cambiar de pestana en el navegador de ayuda" },
        @{ Key = "shift+tab";              Desc = "Ciclar nivel de potencia (low, medium, high)" },
        @{ Key = "home / end";             Desc = "Mover el cursor al inicio o final de linea" },
        @{ Key = "backspace";              Desc = "Borrar el caracter anterior" },
        @{ Key = "alt+enter, shift+enter"; Desc = "Insertar salto de linea sin enviar" },
        @{ Key = "ctrl+u";                 Desc = "Borrar todo el texto del prompt actual" },
        @{ Key = "ctrl+r";                 Desc = "Buscar en el historial de comandos ejecutados" },
        @{ Key = "f5";                     Desc = "Activar entrada por voz o dictado de audio" }
    )

    $savedCursorVisible = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }

    try {
        Clear-Host
        while ($true) {
            $metrics = Get-VorkConsoleMetrics
            $width = [Math]::Max(20, $metrics.Width - 1)
            $height = [Math]::Max(8, $metrics.Height)
            $compact = $height -lt 14
            $winSize = if ($compact) {
                [Math]::Max(1, [Math]::Min(20, $height - 8))
            } else {
                [Math]::Max(1, [Math]::Min(20, $height - 12))
            }
            $bodyBudget = [Math]::Max(1, $height - 6)
            $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 3))

            # Encabezado con pestanas
            Write-Host ""
            $brand = "${Cyan}${Bold}Vork CLI v$VorkVersion${Reset}   "
            $tabStr = ""
            for ($t = 0; $t -lt $tabs.Count; $t++) {
                $tName = $tabs[$t]
                if ($t -eq $curTab) {
                    $tabStr += "$($CSI)48;2;40;60;90m$($CSI)97;1m  $tName  $Reset "
                } else {
                    $tabStr += "${LeadLight} $tName ${Reset} "
                }
            }
            Write-VorkHelpLine -Width $width -Text "  $brand$tabStr"
            Write-VorkHelpLine -Width $width -Text "  ${Lead}$rule${Reset}"

            switch ($curTab) {
                0 {
                    $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
                    $ws = try { (Get-Location).Path } catch { "~" }
                    $maxWs = [Math]::Max(12, $width - 22)
                    if ((Get-VorkDisplayWidth $ws) -gt $maxWs) { $ws = "..." + $ws.Substring([Math]::Max(0, $ws.Length - ($maxWs - 3))) }

                    $generalLines = @()
                    if ($bodyBudget -ge 14) {
                        $generalLines += ""
                        $generalLines += "  ${White}${Bold}Vork CLI${Reset} ${LeadLight}comprende tu espacio de trabajo, sintetiza voz neuronal, clona timbres,${Reset}"
                        $generalLines += "  ${LeadLight}aisla pistas vocales e instrumentales y orquesta agentes autonomos desde tu terminal.${Reset}"
                        $generalLines += ""
                    }
                    $generalLines += "  ${White}${Bold}Version:${Reset}         ${Cyan}$VorkVersion${Reset}"
                    $generalLines += "  ${White}${Bold}Nivel / Tier:${Reset}    ${Cyan}Vork 3 ($tierStr)${Reset}"
                    $generalLines += "  ${White}${Bold}API Cloud:${Reset}       ${Cyan}$ApiBase (Vork AI)${Reset}"
                    $generalLines += "  ${White}${Bold}Workspace:${Reset}       ${White}$ws${Reset}"
                    $generalLines += "  ${White}${Bold}Tema Activo:${Reset}     ${Cyan}$global:VorkThemeName${Reset}"
                    $generalLines += ""
                    $generalLines += "  ${White}${Bold}Referencia Rapida:${Reset}"
                    $generalLines += "    ${Cyan}/${Reset}   ${LeadLight}Escribe / para ver todos los 40 comandos con barra${Reset}"
                    $generalLines += "    ${Cyan}?${Reset}   ${LeadLight}Presiona ? para abrir este navegador interactivo${Reset}"
                    $generalLines += ""

                    for ($g = 0; $g -lt $bodyBudget; $g++) {
                        if ($g -lt $generalLines.Count) {
                            Write-VorkHelpLine -Width $width -Text $generalLines[$g]
                        } else {
                            Write-Host ""
                        }
                    }
                }
                1 {
                    if (-not $compact) { Write-Host "" }
                    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}Comandos Disponibles ($($allCommands.Count)):${Reset}"
                    if (-not $compact) { Write-Host "" }

                    if ($cmdIdx -lt $cmdTop) { $cmdTop = $cmdIdx }
                    elseif ($cmdIdx -ge ($cmdTop + $winSize)) { $cmdTop = $cmdIdx - $winSize + 1 }
                    $maxTop = [Math]::Max(0, $allCommands.Count - $winSize)
                    if ($cmdTop -gt $maxTop) { $cmdTop = $maxTop }
                    if ($cmdTop -lt 0) { $cmdTop = 0 }

                    for ($k = 0; $k -lt $winSize; $k++) {
                        $itemIdx = $cmdTop + $k
                        if ($itemIdx -lt $allCommands.Count) {
                            $cmdItem = $allCommands[$itemIdx]
                            $cName = $cmdItem.Cmd.PadRight(15)
                            $line = if ($itemIdx -eq $cmdIdx) {
                                "  ${Cyan}${Bold}> ${White}${Bold}$cName${Reset} ${White}$($cmdItem.Desc)${Reset}"
                            } else {
                                "    ${LeadLight}$cName${Reset} ${LeadLight}$($cmdItem.Desc)${Reset}"
                            }
                            Write-VorkHelpLine -Width $width -Text $line
                        }
                    }

                    $rangeEnd = [Math]::Min($allCommands.Count, $cmdTop + $winSize)
                    if ($height -ge 10) {
                        if (-not $compact) { Write-Host "" }
                        Write-VorkHelpLine -Width $width -Text "  ${LeadDark}[$($cmdTop + 1)-$rangeEnd de $($allCommands.Count) comandos]${Reset}"
                    }
                }
                2 {
                    if (-not $compact) { Write-Host "" }
                    Write-VorkHelpLine -Width $width -Text "  ${White}${Bold}Atajos de Teclado ($($shortcuts.Count)):${Reset}"
                    if (-not $compact) { Write-VorkHelpLine -Width $width -Text "  ${LeadLight}/keybindings para personalizar${Reset}" }
                    if (-not $compact) { Write-Host "" }

                    if ($scIdx -lt $scTop) { $scTop = $scIdx }
                    elseif ($scIdx -ge ($scTop + $winSize)) { $scTop = $scIdx - $winSize + 1 }
                    $scMaxTop = [Math]::Max(0, $shortcuts.Count - $winSize)
                    if ($scTop -gt $scMaxTop) { $scTop = $scMaxTop }
                    if ($scTop -lt 0) { $scTop = 0 }

                    for ($s = 0; $s -lt $winSize; $s++) {
                        $itemIdx = $scTop + $s
                        if ($itemIdx -lt $shortcuts.Count) {
                            $scItem = $shortcuts[$itemIdx]
                            $sKey = $scItem.Key.PadRight(20)
                            $line = if ($itemIdx -eq $scIdx) {
                                "  ${Cyan}${Bold}> ${White}${Bold}$sKey${Reset} ${White}$($scItem.Desc)${Reset}"
                            } else {
                                "    ${LeadLight}$sKey${Reset} ${LeadLight}$($scItem.Desc)${Reset}"
                            }
                            Write-VorkHelpLine -Width $width -Text $line
                        }
                    }

                    $rangeEnd = [Math]::Min($shortcuts.Count, $scTop + $winSize)
                    if ($height -ge 10) {
                        if (-not $compact) { Write-Host "" }
                        Write-VorkHelpLine -Width $width -Text "  ${LeadDark}[$($scTop + 1)-$rangeEnd de $($shortcuts.Count) atajos]${Reset}"
                    }
                }
            }

            Write-Host ""
            Write-VorkHelpLine -Width $width -Text "  ${Lead}$rule${Reset}"
            $footer = if ($curTab -eq 1) {
                "  ${LeadLight}Teclado: ${Cyan}$([char]0x2191)/$([char]0x2193)${Reset} ${LeadLight}Navegar  ${Cyan}enter${Reset} ${LeadLight}Seleccionar  ${Cyan}$([char]0x2190)/$([char]0x2192)/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
            } else {
                "  ${LeadLight}Teclado: ${Cyan}$([char]0x2191)/$([char]0x2193)${Reset} ${LeadLight}Navegar  ${Cyan}$([char]0x2190)/$([char]0x2192)/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
            }
            Write-VorkHelpLine -Width $width -Text $footer

            $wait = Wait-VorkConsoleKey
            if ($wait.Resized) {
                Clear-Host
                continue
            }

            $key = $wait.Key
            if (-not $key) { continue }

            if (Test-VorkCtrlC -Key $key) { return $null }
            if ($key.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Q) { return $null }

            if ($key.Key -in [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) {
                $curTab = ($curTab + 1) % $tabs.Count
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                $curTab = if ($curTab -gt 0) { $curTab - 1 } else { $tabs.Count - 1 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                if ($curTab -eq 1) {
                    $cmdIdx = if ($cmdIdx -gt 0) { $cmdIdx - 1 } else { $allCommands.Count - 1 }
                } elseif ($curTab -eq 2) {
                    $scIdx = if ($scIdx -gt 0) { $scIdx - 1 } else { $shortcuts.Count - 1 }
                }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                if ($curTab -eq 1) {
                    $cmdIdx = if ($cmdIdx -lt ($allCommands.Count - 1)) { $cmdIdx + 1 } else { 0 }
                } elseif ($curTab -eq 2) {
                    $scIdx = if ($scIdx -lt ($shortcuts.Count - 1)) { $scIdx + 1 } else { 0 }
                }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Home) {
                if ($curTab -eq 1) { $cmdIdx = 0 }
                elseif ($curTab -eq 2) { $scIdx = 0 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::End) {
                if ($curTab -eq 1) { $cmdIdx = $allCommands.Count - 1 }
                elseif ($curTab -eq 2) { $scIdx = $shortcuts.Count - 1 }
                Clear-Host
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($curTab -eq 1) { return $allCommands[$cmdIdx].Cmd }
                return $null
            }
        }
    } finally {
        try { [Console]::TreatControlCAsInput = $false } catch { }
        try { [Console]::CursorVisible = $savedCursorVisible } catch { }
    }
}
