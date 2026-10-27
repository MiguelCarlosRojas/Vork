<#
.SYNOPSIS
    Vork CLI - Modulo UI: Catalogo Visual de los 9 Pilares Operacionales
#>

function Show-Shortcuts {
    Write-Host ""
    Write-Host "  ${White}${Bold}VORK CLI · ATAJOS & COMANDOS RAPIDOS${Reset}"
    Write-Host "  ${Cyan}  /slash${Reset}          ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host "  ${Cyan}  /model${Reset}          ${Dim}Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)${Reset}"
    Write-Host "  ${Cyan}  /help${Reset}           ${Dim}Ver catalogo detallado de los 9 pilares${Reset}"
    Write-Host "  ${Cyan}  /clear, cls${Reset}     ${Dim}Limpiar pantalla y refrescar banner${Reset}"
    Write-Host "  ${Cyan}  /exit, quit, q${Reset}  ${Dim}Salir de la sesion interactiva${Reset}"
    Write-Host "  ${Cyan}  /ping, /health${Reset}  ${Dim}Comprobar conexion con el backend ($ApiBase)${Reset}"
    Write-Host "  ${Cyan}  /update${Reset}         ${Dim}Actualizar Vork CLI al instante${Reset}"
    Write-Host ""
    Write-Host "  ${Dim}Pilares directos: translate, tts, clone, media, separate, image, remove-bg, agents${Reset}"
    Wait-VorkGoBack
    Write-Host ""
}

function Show-Help {
    Show-Banner
    Write-Host "$White$Bold  SINTAXIS:$Reset"
    Write-Host "    $Yellow$Bold vork$Reset $Cyan<comando>$Reset $White [argumentos]$Reset   ${Dim}(Alias: vk, vork-cli, ct)${Reset}"
    Write-Host ""

    Write-Host "$White$Bold  LOS 9 PILARES OPERACIONALES:$Reset"
    
    # Pillar 01
    Write-Host "  ${Cyan}╭─ ${Bold}[01] Vork Traductor en la Nube${Reset} ${Dim}· +200 idiomas por lotes${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork translate${Reset} ${White}<texto>${Reset} ${Gray}-To <iso>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork translate 'Hola mundo' -To en${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"
    
    # Pillar 02
    Write-Host "  ${Cyan}╭─ ${Bold}[02] Vork Texto a Voz Neuronal (TTS)${Reset} ${Dim}· 24 voces humanas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork tts${Reset} ${White}<texto>${Reset} ${Gray}-Voice <id> -Out <archivo>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork tts 'Bienvenido a Vork' -Voice es-ES-AlvaroNeural -Out voz.mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 03
    Write-Host "  ${Cyan}╭─ ${Bold}[03] Vork Clonacion de Voz IA${Reset} ${Dim}· Modelado timbrico F0${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork clone${Reset} ${Gray}-Audio <muestra> -Text <guion>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork clone -Audio muestra.wav -Text 'Texto sintetizado'${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 04
    Write-Host "  ${Cyan}╭─ ${Bold}[04] Vork Conversor Multimedia${Reset} ${Dim}· YouTube, TikTok, IG a MP3/MP4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork media${Reset} ${White}<url>${Reset} ${Gray}-Format <mp3|mp4> -Quality 320${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork media 'https://youtube.com/watch?v=...' -Format mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 05
    Write-Host "  ${Cyan}╭─ ${Bold}[05] Vork Separador de Stems${Reset} ${Dim}· Acapella / Karaoke con Demucs v4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork separate${Reset} ${White}<url_o_archivo>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork separate cancion.mp3${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 06
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 07
    Write-Host "  ${Cyan}╭─ ${Bold}[07] Vork Conversor de Imagenes${Reset} ${Dim}· PNG, JPG, WEBP, ICO, AVIF${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork image${Reset} ${White}<archivo>${Reset} ${Gray}-Format <formato>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork image logo.png -Format webp -Quality 90${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 08
    Write-Host "  ${Cyan}╭─ ${Bold}[08] Vork Estudio de Fondo IA${Reset} ${Dim}· U2-Net silueta y transparente${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork remove-bg${Reset} ${White}<archivo>${Reset} ${Gray}-Out <archivo.png>${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Dim}Ej: vork remove-bg foto.jpg -Out limpia.png${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Pillar 09
    Write-Host "  ${Cyan}╭─ ${Bold}[09] Vork Agentes Autónomos & TUI${Reset} ${Dim}· Modo orquestador de terminal${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vork agents${Reset}  ${White}/${Reset} ${Yellow}vork tui${Reset}   ${Dim}· Orquestar subagentes interactivos${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}vk${Reset}                   ${Dim}· Alias ultracorto para ejecutar Vork CLI${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    Write-Host ""
    Write-Host "$White$Bold  MANTENIMIENTO & ESTADO:$Reset"
    Write-Host "    $Yellow vork update$Reset     ${Dim}Sincroniza y actualiza Vork CLI al instante${Reset}"
    Write-Host "    $Yellow vork health$Reset     ${Dim}Comprueba la telemetria y estado de los 9 pilares${Reset}"
    Write-Host "    $Yellow vork version$Reset    ${Dim}Muestra detalles de arquitectura y version${Reset}"
    Write-Host "    $Yellow vork slash$Reset      ${Dim}Ver los 40 comandos con barra (/)${Reset}"
    Write-Host ""
}

function Show-SlashCommands {
    Show-Banner
    Write-Host "$White$Bold  CATALOGO COMPLETO DE LOS 40 COMANDOS CON BARRA (/):$Reset"
    Write-Host "  ${Dim}Uso: vork /<comando> o en la consola interactiva TUI${Reset}"
    Write-Host ""

    # Categoria 1: Pilares (9)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 1] Los 9 Pilares Operacionales (9)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/translate${Reset}  ${White}· Traducción neuronal por lotes en +200 idiomas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/tts${Reset}        ${White}· Síntesis de voz con 24 voces neuronales humanas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/clone${Reset}      ${White}· Clonación vocal IA y modelado espectral F0${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/media${Reset}      ${White}· Conversión multimedia YouTube, TikTok, IG a MP3/MP4${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/separate${Reset}   ${White}· Aislamiento de Stems Acapella/Karaoke (Demucs v4)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/image${Reset}      ${White}· Conversor universal PNG, JPG, WEBP, ICO, AVIF${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/remove-bg${Reset}  ${White}· Silueta inteligente y eliminación de fondo IA${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/agents${Reset}     ${White}· Orquestación de subagentes en terminal interactiva${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 2: Agentes & Planificacion (8)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 2] Agentes Autónomos & Planificación IA (8)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/goal${Reset}       ${White}· Modo autónomo continuo para tareas exhaustivas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/plan${Reset}       ${White}· Planificación guiada y desglose paso a paso${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/grill-me${Reset}   ${White}· Entrevista interactiva para decisiones de diseño${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/teamwork${Reset}   ${White}· Coordinación con múltiples subagentes concurrentes${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/boost${Reset}      ${White}· Razonamiento profundo con verificación estricta${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/learn${Reset}      ${White}· Persistir reglas, correcciones y preferencias${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/browser${Reset}    ${White}· Navegación e interacción web automatizada${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/automation${Reset} ${White}· Diseñar y programar tareas en segundo plano${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 3: Sesion & Memoria (7)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 3] Contexto, Sesión & Memoria (7)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/compact${Reset}    ${White}· Compactar historial para liberar ventana de contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/clear${Reset}      ${White}· Limpiar pantalla de terminal conservando la sesión${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/reset${Reset}      ${White}· Reiniciar variables y contexto de la sesión a cero${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/history${Reset}    ${White}· Explorar historial cronológico de comandos ejecutados${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/save${Reset}       ${White}· Guardar estado de sesión, artefactos y contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/resume${Reset}     ${White}· Reanudar una sesión previa o restaurar estado${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/undo${Reset}       ${White}· Deshacer la última acción o cambio de código${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 4: Desarrollo, Git & Codigo (4)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 4] Código, Auditoría & Flujo de Trabajo (4)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/status${Reset}     ${White}· Inspeccionar estado del entorno, archivos y tareas activas${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/review${Reset}     ${White}· Auditoría de código, buenas prácticas y seguridad${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/bug${Reset}        ${White}· Diagnóstico y depuración asistida de excepciones${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/refactor${Reset}   ${White}· Reestructurar y optimizar código sin alterar salida${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 5: Configuracion (6)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 5] Configuración & Preferencias (6)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/config${Reset}     ${White}· Ajustar permisos, temas visuales y preferencias${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/keybindings${Reset}${White}· Personalizar atajos de teclado y combinaciones${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/permissions${Reset}${White}· Administrar permisos de herramientas y comandos${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/model${Reset}      ${White}· Cambiar modelo IA y nivel de esfuerzo (Switch Model & Effort)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/theme${Reset}      ${White}· Alternar temas visuales (Dark, Cyberpunk, Coral)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/env${Reset}        ${White}· Consultar y gestionar variables de entorno activas${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"

    # Categoria 6: Sistema & Utilidades (6)
    Write-Host "  ${Cyan}╭─ ${Bold}[CATEGORIA 6] Sistema, Telemetría & Utilidades (6)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/help${Reset}       ${White}· Manual interactivo de comandos y atajos de teclado${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/update${Reset}     ${White}· Sincronizar y actualizar Vork CLI a la última versión${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/health${Reset}     ${White}· Telemetría en tiempo real de los 9 pilares${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/ping${Reset}       ${White}· Prueba de latencia ultrarrápida (0ms) hacia la nube${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/docs${Reset}       ${White}· Abrir la documentación oficial de Vork en el navegador${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${Yellow}/exit${Reset}       ${White}· Cerrar la sesión de terminal de forma segura${Reset}"
    Write-Host "  ${Cyan}╰────────────────────────────────────────────────────────────${Reset}"
    Wait-VorkGoBack
    Write-Host ""
}

# ========================================================
# NAVEGADOR DE AYUDA INTERACTIVO (?) (MODAL MULTIPESTAÑA VORK)
# ========================================================

function Show-InteractiveHelpModal {
    $tabs = @("general", "commands", "shortcuts")
    $curTab = 0
    $cmdIdx = 0
    $scIdx = 0
    $winSize = 16
    $topIdx = 0

    $allCommands = @(
        @{ Cmd = "/translate";   Desc = "Traducción neuronal por lotes en +200 idiomas" },
        @{ Cmd = "/tts";         Desc = "Síntesis de voz con 24 voces neuronales humanas" },
        @{ Cmd = "/clone";       Desc = "Clonación vocal IA y modelado espectral F0" },
        @{ Cmd = "/media";       Desc = "Conversión multimedia YouTube, TikTok, IG a MP3/MP4" },
        @{ Cmd = "/separate";    Desc = "Aislamiento de Stems Acapella/Karaoke (Demucs v4)" },
        @{ Cmd = "/image";       Desc = "Conversor universal PNG, JPG, WEBP, ICO, AVIF" },
        @{ Cmd = "/remove-bg";   Desc = "Silueta inteligente y eliminación de fondo IA" },
        @{ Cmd = "/agents";      Desc = "Orquestación de subagentes en terminal interactiva" },
        @{ Cmd = "/goal";        Desc = "Modo autónomo continuo para tareas exhaustivas" },
        @{ Cmd = "/plan";        Desc = "Planificación guiada y desglose paso a paso" },
        @{ Cmd = "/grill-me";    Desc = "Entrevista interactiva para decisiones de diseño" },
        @{ Cmd = "/teamwork";    Desc = "Coordinación con múltiples subagentes concurrentes" },
        @{ Cmd = "/boost";       Desc = "Razonamiento profundo con verificación estricta" },
        @{ Cmd = "/learn";       Desc = "Persistir reglas, correcciones y preferencias" },
        @{ Cmd = "/browser";     Desc = "Navegación e interacción web automatizada" },
        @{ Cmd = "/automation";  Desc = "Diseñar y programar tareas en segundo plano" },
        @{ Cmd = "/compact";     Desc = "Compactar historial para liberar ventana de contexto" },
        @{ Cmd = "/clear";       Desc = "Limpiar pantalla de terminal conservando la sesión" },
        @{ Cmd = "/reset";       Desc = "Reiniciar variables y contexto de la sesión a cero" },
        @{ Cmd = "/history";     Desc = "Explorar historial cronológico de comandos ejecutados" },
        @{ Cmd = "/save";        Desc = "Guardar estado de sesión, artefactos y contexto" },
        @{ Cmd = "/resume";      Desc = "Reanudar una sesión previa o restaurar estado" },
        @{ Cmd = "/undo";        Desc = "Deshacer la última acción o cambio de código" },
        @{ Cmd = "/status";      Desc = "Telemetría y estado operativo en vivo de los 9 pilares" },
        @{ Cmd = "/review";      Desc = "Auditoría de código, buenas prácticas y seguridad" },
        @{ Cmd = "/bug";         Desc = "Diagnóstico y depuración asistida de excepciones" },
        @{ Cmd = "/refactor";    Desc = "Reestructurar y optimizar código sin alterar salida" },
        @{ Cmd = "/config";      Desc = "Ajustar permisos, temas visuales y preferencias" },
        @{ Cmd = "/keybindings"; Desc = "Personalizar atajos de teclado y combinaciones" },
        @{ Cmd = "/permissions"; Desc = "Administrar permisos de herramientas y comandos" },
        @{ Cmd = "/model";       Desc = "Configurar modelo Vork 3 y nivel de potencia" },
        @{ Cmd = "/theme";       Desc = "Alternar entre los 10 temas visuales oficiales" },
        @{ Cmd = "/env";         Desc = "Consultar y gestionar variables de entorno activas" },
        @{ Cmd = "/help";        Desc = "Manual interactivo de comandos y atajos de teclado" },
        @{ Cmd = "/update";      Desc = "Sincronizar y actualizar Vork CLI a la última versión" },
        @{ Cmd = "/health";      Desc = "Telemetría en tiempo real de los 9 pilares" },
        @{ Cmd = "/ping";        Desc = "Prueba de latencia ultrarrápida (0ms) hacia la nube" },
        @{ Cmd = "/docs";        Desc = "Abrir la documentación oficial de Vork en el navegador" },
        @{ Cmd = "/exit";        Desc = "Cerrar la sesión de terminal de forma segura" }
    )

    $shortcuts = @(
        @{ Key = "/";                       Desc = "Abrir selector interactivo de comandos con barra" },
        @{ Key = "?";                       Desc = "Abrir este navegador de ayuda interactivo" },
        @{ Key = "enter";                   Desc = "Enviar mensaje o confirmar selección" },
        @{ Key = "tab";                     Desc = "Autocompletar comando o ciclar pestañas" },
        @{ Key = "esc, ctrl+c";             Desc = "Volver atrás / descartar menú / cancelar" },
        @{ Key = "ctrl+l";                  Desc = "Limpiar pantalla de la terminal" },
        @{ Key = "ctrl+d";                  Desc = "Salir del CLI de forma segura" },
        @{ Key = "up / down";               Desc = "Navegar historial de comandos o menús" },
        @{ Key = "left / right";            Desc = "Cambiar de pestaña en el navegador de ayuda" },
        @{ Key = "shift+tab";               Desc = "Ciclar nivel de potencia (low, medium, high)" },
        @{ Key = "home / end";              Desc = "Mover el cursor al inicio o final de línea" },
        @{ Key = "backspace";               Desc = "Borrar el carácter anterior" },
        @{ Key = "alt+enter, shift+enter";  Desc = "Insertar salto de línea sin enviar" },
        @{ Key = "ctrl+u";                  Desc = "Borrar todo el texto del prompt actual" },
        @{ Key = "ctrl+r";                  Desc = "Buscar en el historial de comandos ejecutados" },
        @{ Key = "f5";                      Desc = "Activar entrada por voz o dictado de audio" }
    )

    $savedCursorVisible = try { [Console]::CursorVisible } catch { $true }
    try { [Console]::CursorVisible = $false } catch { }

    while ($true) {
        Clear-Host
        $width = try { [Console]::WindowWidth } catch { 120 }
        if ($width -le 20) { $width = 120 }
        $rule = [string]::new([char]0x2500, [Math]::Max(10, $width - 1))

        # Render Header con Pestañas de Navegación
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
        $cycleHint = "${LeadLight}(${Cyan}←/→${Reset}${LeadLight} o ${Cyan}tab${Reset}${LeadLight} para cambiar)${Reset}"
        Write-Host "  $brand$tabStr  $cycleHint"
        Write-Host "  ${Lead}$rule${Reset}"
        Write-Host ""

        # Contenido por pestaña
        switch ($curTab) {
            0 {
                # TAB GENERAL
                Write-Host "  ${White}${Bold}Vork CLI${Reset} ${LeadLight}comprende tu espacio de trabajo, sintetiza voz neuronal, clona timbres,${Reset}"
                Write-Host "  ${LeadLight}aísla pistas vocales e instrumentales y orquesta agentes autónomos desde tu terminal.${Reset}"
                Write-Host ""
                $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
                $ws = (Get-Location).Path
                if ($ws.Length -gt 50) { $ws = "..." + $ws.Substring($ws.Length - 47) }

                Write-Host "  ${White}${Bold}Versión:${Reset}         ${Cyan}3.0.2${Reset}"
                Write-Host "  ${White}${Bold}Nivel / Tier:${Reset}    ${Cyan}Vork 3 ($tierStr)${Reset}"
                Write-Host "  ${White}${Bold}API Cloud:${Reset}       ${Cyan}$ApiBase (Vork AI)${Reset}"
                Write-Host "  ${White}${Bold}Workspace:${Reset}       ${White}$ws${Reset}"
                Write-Host "  ${White}${Bold}Tema Activo:${Reset}     ${Cyan}$global:VorkThemeName${Reset}"
                Write-Host ""
                Write-Host "  ${White}${Bold}Referencia Rápida:${Reset}"
                Write-Host "    ${Cyan}/${Reset}   ${LeadLight}Escribe / para ver todos los 40 comandos con barra${Reset}"
                Write-Host "    ${Cyan}?${Reset}   ${LeadLight}Presiona ? para abrir este navegador interactivo${Reset}"
                Write-Host ""
            }
            1 {
                # TAB COMMANDS
                Write-Host "  ${White}${Bold}Comandos Disponibles (${allCommands.Count}):${Reset}"
                Write-Host ""

                if ($cmdIdx -lt $topIdx) { $topIdx = $cmdIdx }
                elseif ($cmdIdx -ge ($topIdx + $winSize)) { $topIdx = $cmdIdx - $winSize + 1 }
                if ($topIdx -gt ($allCommands.Count - $winSize)) { $topIdx = [Math]::Max(0, $allCommands.Count - $winSize) }
                if ($topIdx -lt 0) { $topIdx = 0 }

                for ($k = 0; $k -lt $winSize; $k++) {
                    $itemIdx = $topIdx + $k
                    if ($itemIdx -lt $allCommands.Count) {
                        $cmdItem = $allCommands[$itemIdx]
                        $cName = $cmdItem.Cmd.PadRight(24)
                        $cDesc = $cmdItem.Desc
                        if ($cDesc.Length -gt ($width - 34)) {
                            $cDesc = $cDesc.Substring(0, [Math]::Max(10, $width - 37)) + "..."
                        }

                        if ($itemIdx -eq $cmdIdx) {
                            Write-Host "  ${Cyan}${Bold}> ${White}${Bold}$cName${Reset} ${White}$cDesc${Reset}"
                        } else {
                            Write-Host "    ${LeadLight}$cName${Reset} ${LeadLight}$cDesc${Reset}"
                        }
                    }
                }

                $rangeEnd = [Math]::Min($allCommands.Count, $topIdx + $winSize)
                Write-Host ""
                Write-Host "  ${LeadDark}[$($topIdx + 1)-$rangeEnd de $($allCommands.Count) comandos]${Reset}"
            }
            2 {
                # TAB SHORTCUTS
                Write-Host "  ${White}${Bold}Atajos de Teclado (${shortcuts.Count}):${Reset}"
                Write-Host "  ${LeadLight}/keybindings para personalizar${Reset}"
                Write-Host ""

                for ($s = 0; $s -lt $shortcuts.Count; $s++) {
                    $scItem = $shortcuts[$s]
                    $sKey = $scItem.Key.PadRight(26)
                    $sDesc = $scItem.Desc
                    if ($s -eq $scIdx) {
                        Write-Host "  ${Cyan}${Bold}> ${White}${Bold}$sKey${Reset} ${White}$sDesc${Reset}"
                    } else {
                        Write-Host "    ${LeadLight}$sKey${Reset} ${LeadLight}$sDesc${Reset}"
                    }
                }

                Write-Host ""
                Write-Host "  ${LeadDark}[1-$($shortcuts.Count) de $($shortcuts.Count) atajos]${Reset}"
            }
        }

        # Footer
        Write-Host ""
        Write-Host "  ${Lead}$rule${Reset}"
        if ($curTab -eq 1) {
            Write-Host "  ${LeadLight}Teclado: ${Cyan}↑/↓${Reset} ${LeadLight}Navegar  ${Cyan}enter${Reset} ${LeadLight}Seleccionar  ${Cyan}←/→/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
        } else {
            Write-Host "  ${LeadLight}Teclado: ${Cyan}↑/↓${Reset} ${LeadLight}Navegar  ${Cyan}←/→/tab${Reset} ${LeadLight}Cambiar Vista  ${Coral}esc${Reset} ${LeadLight}Cerrar${Reset}"
        }

        $key = [Console]::ReadKey($true)

        if ($key.Key -in [ConsoleKey]::Escape, [ConsoleKey]::Q) {
            try { [Console]::CursorVisible = $savedCursorVisible } catch { }
            return $null
        }

        if ($key.Key -in [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) {
            $curTab = ($curTab + 1) % $tabs.Count
            continue
        }

        if ($key.Key -eq [ConsoleKey]::LeftArrow) {
            $curTab = if ($curTab -gt 0) { $curTab - 1 } else { $tabs.Count - 1 }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            if ($curTab -eq 1) {
                $cmdIdx = if ($cmdIdx -gt 0) { $cmdIdx - 1 } else { $allCommands.Count - 1 }
            } elseif ($curTab -eq 2) {
                $scIdx = if ($scIdx -gt 0) { $scIdx - 1 } else { $shortcuts.Count - 1 }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            if ($curTab -eq 1) {
                $cmdIdx = if ($cmdIdx -lt ($allCommands.Count - 1)) { $cmdIdx + 1 } else { 0 }
            } elseif ($curTab -eq 2) {
                $scIdx = if ($scIdx -lt ($shortcuts.Count - 1)) { $scIdx + 1 } else { 0 }
            }
            continue
        }

        if ($key.Key -eq [ConsoleKey]::Enter) {
            try { [Console]::CursorVisible = $savedCursorVisible } catch { }
            if ($curTab -eq 1) {
                return $allCommands[$cmdIdx].Cmd
            }
            return $null
        }
    }
}
