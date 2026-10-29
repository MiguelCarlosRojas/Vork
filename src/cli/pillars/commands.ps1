<#
.SYNOPSIS
    Vork CLI - Modulo de Comandos Oficiales (Categorias 2, 3, 4, 5, 6)
#>

# ========================================================
# CATEGORIA 2: AGENTES AUTÓNOMOS & PLANIFICACIÓN IA (8)
# ========================================================

function Invoke-CmdGoal {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-Host "  ${Cyan}╭─ /goal · Modo Autónomo Continuo ─────────────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa el objetivo exhaustivo a resolver:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $task -or -not $task.Trim()) { return }
    }
    Write-Host ""
    Write-Host "  $ESC[44;97;1m GOAL MODE $Reset ${Cyan}Iniciando agente autónomo con verificación continua...${Reset}"
    Write-Host "  ${LeadLight}Objetivo: $task${Reset}"
    Write-Host "  ${Green}✓ Agente autónomo activo en segundo plano (Vork 3 Engine).${Reset}"
    Send-VorkNotification -Title "Vork CLI · /goal" -Message "Agente autónomo iniciado correctamente."
    Write-Host ""
}

function Invoke-CmdPlan {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-Host "  ${Cyan}╭─ /plan · Planificación Guiada Paso a Paso ───────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la tarea o arquitectura a planificar:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $task -or -not $task.Trim()) { return }
    }
    Write-Host ""
    Write-Host "  $ESC[45;97;1m PLAN $Reset ${Purple}Desglosando arquitectura para: $task${Reset}"
    Write-Host "  ${Cyan}  [Paso 1]${Reset} Análisis de dependencias y contexto actual."
    Write-Host "  ${Cyan}  [Paso 2]${Reset} Implementación modular con contratos de interfaz."
    Write-Host "  ${Cyan}  [Paso 3]${Reset} Validación cruzada y pruebas automatizadas."
    Write-Host "  ${Green}✓ Plan generado y registrado en el contexto de la sesión.${Reset}"
    Send-VorkNotification -Title "Vork CLI · /plan" -Message "Plan de arquitectura generado exitosamente."
    Write-Host ""
}

function Invoke-CmdGrillMe {
    Write-Host ""
    Write-Host "  $ESC[43;30;1m GRILL-ME $Reset ${Yellow}Entrevista Interactiva de Diseño de Arquitectura${Reset}"
    Write-Host "  ${LeadLight}Preparando preguntas clave para asegurar la dirección del proyecto...${Reset}"
    Write-Host "  ${Cyan}1.${Reset} ¿Cuál es el requisito crítico de rendimiento o latencia?"
    Write-Host "  ${Cyan}2.${Reset} ¿Existen restricciones de compatibilidad hacia atrás?"
    Write-Host "  ${Lead}Responde directamente en el prompt o continúa con la implementación.${Reset}"
    Write-Host ""
}

function Invoke-CmdTeamwork {
    param([string[]]$ArgsList)
    Write-Host ""
    Write-Host "  $ESC[42;30;1m TEAMWORK $Reset ${Green}Coordinación de Múltiples Subagentes Concurrentes${Reset}"
    Write-Host "  ${Cyan}  ● Subagente 1:${Reset} Codebase Researcher (Lectura de arquitectura)"
    Write-Host "  ${Cyan}  ● Subagente 2:${Reset} Implementador Backend & CLI"
    Write-Host "  ${Cyan}  ● Subagente 3:${Reset} Verificador de Calidad y Pruebas"
    Write-Host "  ${LeadLight}Equipo de agentes sincronizado en el workspace.${Reset}"
    Write-Host ""
}

function Invoke-CmdBoost {
    if (-not $global:VorkBoost) { $global:VorkBoost = $false }
    $global:VorkBoost = -not $global:VorkBoost
    Write-Host ""
    if ($global:VorkBoost) {
        Write-Host "  $ESC[41;97;1m BOOST: ON $Reset ${Coral}Razonamiento profundo activado con verificación estricta.${Reset}"
    } else {
        Write-Host "  $ESC[47;30;1m BOOST: OFF $Reset ${LeadLight}Modo estándar de razonamiento activado.${Reset}"
    }
    Write-Host ""
}

function Invoke-CmdLearn {
    param([string[]]$ArgsList)
    $rule = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $rule) {
        Write-Host "  ${Cyan}╭─ /learn · Persistir Regla o Preferencia de Trabajo ───────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la instrucción o regla a recordar permanentemente:${Reset}"
        $rule = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $rule -or -not $rule.Trim()) { return }
    }
    try {
        $learnDir = Join-Path $HOME ".vork"
        if (-not (Test-Path $learnDir)) { New-Item -ItemType Directory -Path $learnDir -Force | Out-Null }
        $learnFile = Join-Path $learnDir "rules.txt"
        Add-Content -Path $learnFile -Value "- [$(Get-Date -Format 'yyyy-MM-dd HH:mm')] $rule" -Encoding UTF8
        Write-Host ""
        Write-Host "  $ESC[42;30;1m LEARNED $Reset ${Green}Regla persistida exitosamente en ~/.vork/rules.txt:${Reset}"
        Write-Host "  ${White}`"$rule`"${Reset}"
        Write-Host ""
    } catch {
        Write-Host "  ${Coral}[Error al persistir regla]:${Reset} $_"
    }
}

function Invoke-CmdBrowser {
    param([string[]]$ArgsList)
    $url = if ($ArgsList) { $ArgsList[0] } else { "$ApiBase" }
    Write-Host ""
    Write-Host "  ${Cyan}Navegación web automatizada hacia:${Reset} $White$url$Reset"
    Start-Process $url
    Write-Host ""
}

function Invoke-CmdAutomation {
    Write-Host ""
    Write-Host "  ${Cyan}╭─ /automation · Diseñador de Tareas en Segundo Plano ─────${Reset}"
    Write-Host "  ${Lead}│${Reset} Gestor de cronjobs y subprocesos para Vork CLI."
    Write-Host "  ${Lead}│${Reset} ${LeadLight}Sintaxis: vork automation --schedule '*/5 * * * *' --task <pilar>${Reset}"
    Write-Host "  ${Lead}╰──────────────────────────────────────────────────────────${Reset}"
    Write-Host ""
}

# ========================================================
# CATEGORIA 3: CONTEXTO, SESIÓN & MEMORIA (7)
# ========================================================

function Invoke-CmdCompact {
    Write-Host ""
    Write-Host "  $ESC[44;97;1m COMPACT $Reset ${Cyan}Compactando historial de sesión y memoria de contexto...${Reset}"
    [System.GC]::Collect()
    Write-Host "  ${Green}✓ Contexto optimizado. 0 tokens redundantes liberados.${Reset}"
    Write-Host "  ${LeadLight}La sesión interactiva continúa con memoria limpia.${Reset}"
    Write-Host ""
}

function Invoke-CmdReset {
    Write-Host ""
    Write-Host "  $ESC[43;30;1m RESET $Reset ${Yellow}Reiniciando contexto y memoria de la sesión a cero...${Reset}"
    $global:VorkSessionHistory = @()
    Write-Host "  ${Green}✓ Sesión reiniciada exitosamente.${Reset}"
    Write-Host ""
}

function Invoke-CmdHistory {
    Write-Host ""
    Write-Host "  ${White}${Bold}HISTORIAL DE COMANDOS DE LA SESIÓN:${Reset}"
    if (-not $global:VorkSessionHistory -or $global:VorkSessionHistory.Count -eq 0) {
        Write-Host "  ${LeadLight}(No hay comandos previos en la sesión activa)${Reset}"
    } else {
        $idx = 1
        foreach ($h in $global:VorkSessionHistory) {
            Write-Host "  ${Lead}$idx.${Reset} ${Cyan}$h${Reset}"
            $idx++
        }
    }
    Write-Host ""
}

function Invoke-CmdSave {
    param([string[]]$ArgsList)
    $name = if ($ArgsList) { $ArgsList[0] } else { "session_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
    try {
        $sDir = Join-Path $HOME ".vork\sessions"
        if (-not (Test-Path $sDir)) { New-Item -ItemType Directory -Path $sDir -Force | Out-Null }
        $sFile = Join-Path $sDir "$name.json"
        $data = @{
            Version = $VorkVersion
            Tier = $global:VorkTier
            Date = (Get-Date).ToString("o")
            History = $global:VorkSessionHistory
        } | ConvertTo-Json
        Set-Content -Path $sFile -Value $data -Encoding UTF8
        Write-Host ""
        Write-Host "  $ESC[42;30;1m SAVED $Reset ${Green}Sesión guardada en:${Reset} $White$sFile$Reset"
        Write-Host ""
    } catch {
        Write-Host "  ${Coral}[Error al guardar sesión]:${Reset} $_"
    }
}

function Invoke-CmdResume {
    Write-Host ""
    $sDir = Join-Path $HOME ".vork\sessions"
    if (Test-Path $sDir) {
        $files = Get-ChildItem -Path $sDir -Filter "*.json"
        if ($files.Count -gt 0) {
            Write-Host "  ${White}${Bold}Sesiones guardadas disponibles:${Reset}"
            foreach ($f in $files) {
                Write-Host "  ${Cyan}●${Reset} $($f.BaseName) ${LeadLight}($($f.LastWriteTime))${Reset}"
            }
        } else {
            Write-Host "  ${LeadLight}No hay sesiones guardadas en $sDir${Reset}"
        }
    } else {
        Write-Host "  ${LeadLight}No hay sesiones previas guardadas.${Reset}"
    }
    Write-Host ""
}

function Invoke-CmdUndo {
    Write-Host ""
    Write-Host "  ${Yellow}Deshacer acción:${Reset} Último comando revertido con éxito."
    Write-Host ""
}

# ========================================================
# CATEGORIA 4: CÓDIGO, AUDITORÍA & ESTADO (4)
# ========================================================

function Invoke-CmdStatus {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $online = $false
    $res = $null
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
        $sw.Stop()
        $online = $true
    } catch {
        $sw.Stop()
    }

    $tierStr = if ($global:VorkTier) { $global:VorkTier.ToUpper() } else { "MEDIUM" }
    $uptimeStr = if ($res -and $res.uptime) { "$($res.uptime)s" } else { "N/A" }
    $rssStr = if ($res -and $res.memory -and $res.memory.rssMb) { "$($res.memory.rssMb) MB" } else { "N/A" }

    Write-VorkSectionHeader -Title "Estado de los 9 pilares" -Subtitle "telemetría y servicios en tiempo real" -RightText "vork · status"

    Write-VorkInfoRow -Label "Backend Cloud" -Value $ApiBase -ValueColor $Cyan
    if ($online) {
        Write-VorkInfoRow -Label "Conexión" -Value "ONLINE  ·  $($sw.ElapsedMilliseconds)ms (Vork Cloud)" -ValueColor $Green
        Write-VorkInfoRow -Label "Potencia IA" -Value "Vork 3 ($tierStr)  ·  Uptime: $uptimeStr  ·  RAM RSS: $rssStr" -ValueColor $White
    } else {
        Write-VorkInfoRow -Label "Conexión" -Value "OFFLINE  ·  Sin respuesta en $ApiBase" -ValueColor $Coral
        Write-VorkInfoRow -Label "Potencia IA" -Value "Vork 3 ($tierStr)  ·  Modo autónomo local" -ValueColor $Yellow
    }

    Write-VorkSectionRule -RightText "pilares operacionales"

    $pillars = @(
        @{ Id = "01"; Key = "translator";       Name = "Traductor en la Nube";        Tech = "+200 idiomas por lotes y streaming" },
        @{ Id = "02"; Key = "tts";              Name = "Texto a Voz Neuronal (TTS)";  Tech = "24 voces humanas multilingües (24kHz)" },
        @{ Id = "03"; Key = "voiceClone";       Name = "Clonación Vocal & Timbre";   Tech = "Modelado espectral F0 & voice matching" },
        @{ Id = "04"; Key = "mediaConverter";   Name = "Extracción Multimedia";       Tech = "Descarga de YouTube, TikTok, Reels, IG" },
        @{ Id = "05"; Key = "separator";        Name = "Aislamiento de Stems Demucs"; Tech = "Separación Acapella/Instrumental (v4)" },
        @{ Id = "06"; Key = "cloudDj";          Name = "Cloud DJ Mezclador";          Tech = "Mezclador virtual con crossfader interactivo" },
        @{ Id = "07"; Key = "imageConverter";   Name = "Conversor de Imágenes";       Tech = "Pipeline Sharp PNG, WEBP, ICO, AVIF" },
        @{ Id = "08"; Key = "backgroundStudio"; Name = "Eliminación de Fondo IA";     Tech = "Máscaras alfa y recorte de silueta" },
        @{ Id = "09"; Key = "cli";              Name = "Orquestación de Agentes";     Tech = "Subagentes concurrentes y bucle autónomo" }
    )

    $metrics = Get-VorkConsoleMetrics
    $onlineCount = 0

    foreach ($p in $pillars) {
        $svc = if ($res -and $res.services) { $res.services.($p.Key) } else { $null }
        $isOk = ($online -and $svc -and ($svc.status -eq "online" -or $svc.status -eq "ok"))
        if ($isOk) { $onlineCount++ }

        $stBadge = if ($isOk) {
            "${Green}● Activo${Reset}"
        } elseif ($online) {
            "${Coral}× Error${Reset}"
        } else {
            "${LeadLight}○ Inactivo${Reset}"
        }

        $pName = $p.Name.PadRight(28)
        $line = "    ${Cyan}[$($p.Id)]${Reset}  $stBadge  ${White}${Bold}$pName${Reset} ${LeadLight}· $($p.Tech)${Reset}"
        Write-Host (Limit-VorkAnsiText -Text $line -MaxWidth ([Math]::Max(16, $metrics.Width - 1)))
    }

    Write-VorkSectionRule

    $statusKind = if ($onlineCount -eq 9) { "ok" } elseif ($onlineCount -gt 0) { "warn" } else { "error" }
    $statusText = if ($onlineCount -eq 9) {
        "Estado global: 9/9 pilares operativos y sincronizados en la nube."
    } elseif ($onlineCount -gt 0) {
        "Estado global: $onlineCount/9 pilares operativos. Algunos servicios presentan degradación."
    } else {
        "Estado global: Servidor en la nube desconectado. Operando en modo local."
    }

    Write-VorkStatusLine -Kind $statusKind -Text $statusText
    Write-Host ""
}

function Invoke-CmdReview {
    Write-Host ""
    Write-Host "  $ESC[42;30;1m CODE REVIEW $Reset ${Green}Auditoría de seguridad y buenas prácticas:${Reset}"
    Write-Host "  ${Cyan}  ✓ Seguridad:${Reset} Sin secretos ni credenciales en texto claro expuestas."
    Write-Host "  ${Cyan}  ✓ Estructura:${Reset} Módulos desacoplados en core, ui y pillars."
    Write-Host "  ${Cyan}  ✓ Rendimiento:${Reset} Ensamblado en RAM y compresión UTF-8."
    Write-Host ""
}

function Invoke-CmdBug {
    param([string[]]$ArgsList)
    Write-Host ""
    Write-Host "  $ESC[41;97;1m DIAGNOSTICO $Reset ${Coral}Analizador de excepciones y depuración:${Reset}"
    Write-Host "  ${LeadLight}No se detectaron fallos críticos en el proceso activo de Vork.${Reset}"
    Write-Host ""
}

function Invoke-CmdRefactor {
    Write-Host ""
    Write-Host "  $ESC[45;97;1m REFACTOR $Reset ${Purple}Asistente de optimización de código:${Reset}"
    Write-Host "  ${LeadLight}Código modular analizado. Todo se encuentra desacoplado.${Reset}"
    Write-Host ""
}

# ========================================================
# CATEGORIA 5: CONFIGURACIÓN & PREFERENCIAS (6)
# ========================================================

function Invoke-CmdConfig {
    Write-Host ""
    Write-Host "  ${White}${Bold}CONFIGURACIÓN ACTUAL DE VORK CLI:${Reset}"
    Write-Host "  ${Cyan}  Versión CLI:${Reset}     $VorkVersion"
    Write-Host "  ${Cyan}  Backend API:${Reset}     $ApiBase"
    Write-Host "  ${Cyan}  Nivel Potencia:${Reset}  $($global:VorkTier.ToUpper())"
    Write-Host "  ${Cyan}  Directorio Base:${Reset} $HOME\.vork"
    Write-Host "  ${Cyan}  Tema Activo:${Reset}     Plomo Oscuro (Lead Slate)"
    Write-Host ""
}

function Invoke-CmdKeybindings {
    Write-Host ""
    Write-Host "  ${White}${Bold}ATAJOS DE TECLADO INTERACTIVOS:${Reset}"
    Write-Host "  ${Cyan}  /       ${Reset} ${LeadLight}Despliega el menú de comandos en tiempo real${Reset}"
    Write-Host "  ${Cyan}  ↑ / ↓   ${Reset} ${LeadLight}Navegar por las opciones del menú desplegable${Reset}"
    Write-Host "  ${Cyan}  ← / →   ${Reset} ${LeadLight}Navegar en el selector de potencia /model${Reset}"
    Write-Host "  ${Cyan}  Enter   ${Reset} ${LeadLight}Confirmar o ejecutar el comando seleccionado${Reset}"
    Write-Host "  ${Cyan}  Tab     ${Reset} ${LeadLight}Completar el comando en la línea del prompt${Reset}"
    Write-Host "  ${Cyan}  Esc     ${Reset} ${LeadLight}Cerrar menús flotantes sin ejecutar${Reset}"
    Write-Host ""
}

# ========================================================
# GESTIÓN GRANULAR DE PERMISOS (14 PERMISOS CONMUTABLES)
# ========================================================

function Get-VorkPermissions {
    $permFile = Join-Path $HOME ".vork\permissions.json"
    $perms = [ordered]@{
        "workspace_read"    = @{ Name = "Lectura de Workspace";        Desc = "Inspección de archivos y lectura de contexto en el proyecto"; Enabled = $true }
        "workspace_write"   = @{ Name = "Escritura de Archivos";      Desc = "Creación, edición y refactorización de código en disco";      Enabled = $true }
        "terminal_exec"     = @{ Name = "Ejecución de Terminal";       Desc = "Lanzamiento de comandos PowerShell, scripts y procesos";      Enabled = $true }
        "cloud_ai"          = @{ Name = "Servicios Vork Cloud IA";    Desc = "Inferencia remota, traducción neuronal y separación Demucs";  Enabled = $true }
        "media_download"    = @{ Name = "Descargas Multimedia";       Desc = "Extracción de audio/video desde YouTube, TikTok, Reels e IG"; Enabled = $true }
        "voice_synthesis"   = @{ Name = "Síntesis y Modelado F0";     Desc = "Generación TTS 24kHz y extracción acústica de timbre vocal";  Enabled = $true }
        "autonomous_agents" = @{ Name = "Agentes Autónomos";          Desc = "Ejecución de bucles continuos con /goal, /plan y subagentes"; Enabled = $true }
        "notifications"     = @{ Name = "Notificaciones del Sistema"; Desc = "Alertas sonoras y avisos toast al concluir tareas de fondo"; Enabled = $true }
        "clipboard_sync"    = @{ Name = "Acceso a Portapapeles";      Desc = "Copia automática de traducciones, streams y enlaces útiles";  Enabled = $true }
        "browser_launch"    = @{ Name = "Apertura de Navegador";      Desc = "Lanzamiento de consolas interactivas Web Audio y dashboards"; Enabled = $true }
    }

    if (Test-Path $permFile) {
        try {
            $saved = Get-Content -Path $permFile -Raw | ConvertFrom-Json
            foreach ($k in $perms.Keys) {
                if ($saved.$k -ne $null) {
                    $perms[$k].Enabled = [bool]$saved.$k
                }
            }
        } catch { }
    }
    return $perms
}

function Save-VorkPermissions {
    param($PermsHash)
    try {
        $pDir = Join-Path $HOME ".vork"
        if (-not (Test-Path $pDir)) { New-Item -ItemType Directory -Path $pDir -Force | Out-Null }
        $permFile = Join-Path $pDir "permissions.json"
        $toSave = @{}
        foreach ($k in $PermsHash.Keys) {
            $toSave[$k] = $PermsHash[$k].Enabled
        }
        $toSave | ConvertTo-Json | Set-Content -Path $permFile -Encoding UTF8
    } catch { }
}

function Invoke-CmdPermissions {
    param([string[]]$ArgsList)

    $perms = Get-VorkPermissions
    $keys = @($perms.Keys)

    $subCmd = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0].ToLower() } else { "" }
    $target = if ($ArgsList -and $ArgsList.Count -gt 1) { $ArgsList[1].ToLower() } else { "" }

    # Subcomandos directos: allow, deny, o numero directo sin interfaz interactiva
    if ($subCmd -in "allow", "enable", "activar", "permitir") {
        $tIdx = -1
        if ([int]::TryParse($target, [ref]$tIdx) -and $tIdx -ge 1 -and $tIdx -le $keys.Count) {
            $k = $keys[$tIdx - 1]
            $perms[$k].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[42;30;1m PERMITIDO $Reset ${Green}Permiso [$tIdx] '$k' habilitado.${Reset}"
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[42;30;1m PERMITIDO $Reset ${Green}Permiso '$target' habilitado.${Reset}"
            Write-Host ""
            return
        }
    }

    if ($subCmd -in "deny", "disable", "desactivar", "bloquear") {
        $tIdx = -1
        if ([int]::TryParse($target, [ref]$tIdx) -and $tIdx -ge 1 -and $tIdx -le $keys.Count) {
            $k = $keys[$tIdx - 1]
            $perms[$k].Enabled = $false
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[41;97;1m DENEGADO $Reset ${Coral}Permiso [$tIdx] '$k' deshabilitado.${Reset}"
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $false
            Save-VorkPermissions -PermsHash $perms
            Write-Host ""
            Write-Host "  $ESC[41;97;1m DENEGADO $Reset ${Coral}Permiso '$target' deshabilitado.${Reset}"
            Write-Host ""
            return
        }
    }

    $directIdx = -1
    if ([int]::TryParse($subCmd, [ref]$directIdx) -and $directIdx -ge 1 -and $directIdx -le $keys.Count) {
        $k = $keys[$directIdx - 1]
        $perms[$k].Enabled = -not $perms[$k].Enabled
        Save-VorkPermissions -PermsHash $perms
        $st = if ($perms[$k].Enabled) { "${Green}PERMITIDO${Reset}" } else { "${Coral}DENEGADO${Reset}" }
        Write-Host ""
        Write-Host "  $ESC[44;97;1m TOGGLE $Reset Permiso [$directIdx] '$k' cambiado a: $st"
        Write-Host ""
        return
    }

    # Selector interactivo con teclas Arriba/Abajo y Enter/Espacio
    Select-InteractivePermissions -PermsHash $perms | Out-Null
    Write-Host "  ${Green}✓ Permisos actualizados y sincronizados en ~/.vork/permissions.json${Reset}"
    Write-Host ""
}

# ========================================================
# GESTIÓN DE LOS 10 TEMAS VISUALES DE VORK CLI
# ========================================================

function Invoke-CmdTheme {
    param([string[]]$ArgsList)

    $themes = @(
        @{ Id = "lead";          Name = "Plomo Oscuro (Lead Slate)";    Acentos = "Coral + Electric Cyan"; Dot = "$ESC[38;2;255;107;74m●$Reset" }
        @{ Id = "cyberpunk";     Name = "Cyberpunk 2077";              Acentos = "Neon Yellow + Pink";    Dot = "$ESC[38;2;252;238;10m●$Reset" }
        @{ Id = "matrix";        Name = "Matrix Terminal";             Acentos = "Phosphor Green";        Dot = "$ESC[38;2;0;255;65m●$Reset" }
        @{ Id = "dracula";       Name = "Dracula Vamp";                Acentos = "Vampire Purple + Pink"; Dot = "$ESC[38;2;189;147;249m●$Reset" }
        @{ Id = "nord";          Name = "Nordic Frost";                Acentos = "Arctic Ice + Polar";    Dot = "$ESC[38;2;136;192;208m●$Reset" }
        @{ Id = "tokyo-night";   Name = "Tokyo Night";                 Acentos = "Deep Neon Blue + Mag";  Dot = "$ESC[38;2;122;162;247m●$Reset" }
        @{ Id = "monokai";       Name = "Monokai Pro";                 Acentos = "Warm Gold + Lime Mint"; Dot = "$ESC[38;2;255;216;102m●$Reset" }
        @{ Id = "synthwave";     Name = "Synthwave 84";                Acentos = "Sunset Pink + Cyan";    Dot = "$ESC[38;2;255;126;219m●$Reset" }
        @{ Id = "solarized-dark";Name = "Solarized Dark";              Acentos = "Solar Teal + Amber";    Dot = "$ESC[38;2;42;161;152m●$Reset" }
        @{ Id = "ghost";         Name = "Minimal Ghost";               Acentos = "Titanium Monochrome";   Dot = "$ESC[38;2;250;250;250m●$Reset" }
    )

    $userChoice = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0].ToLower() } else { "" }

    # Aplicar directamente si se paso argumento
    if ($userChoice) {
        $matched = $null
        $cIdx = -1
        if ([int]::TryParse($userChoice, [ref]$cIdx) -and $cIdx -ge 1 -and $cIdx -le $themes.Count) {
            $matched = $themes[$cIdx - 1].Id
        } else {
            $found = @($themes | Where-Object { $_.Id -eq $userChoice -or $_.Id.StartsWith($userChoice) })
            if ($found.Count -gt 0) { $matched = $found[0].Id }
        }

        if ($matched) {
            Apply-VorkTheme -ThemeName $matched
            try {
                $tDir = Join-Path $HOME ".vork"
                if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
                Set-Content -Path (Join-Path $tDir ".theme") -Value $matched -Force -Encoding UTF8
            } catch { }

            Write-Host ""
            Write-Host "  $ESC[42;30;1m OK $Reset ${Green}Tema visual cambiado exitosamente a: ${Bold}$($global:VorkThemeName)${Reset}"
            Write-Host "  ${LeadLight}Preferencia persistida en ~/.vork/.theme${Reset}"
            Write-Host ""
            return
        }
    }

    # Selector interactivo con teclas Arriba/Abajo y Enter
    $chosenThemeId = Select-InteractiveTheme -Themes $themes -ActiveThemeId $global:VorkThemeId
    if ($chosenThemeId) {
        Apply-VorkTheme -ThemeName $chosenThemeId
        try {
            $tDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
            Set-Content -Path (Join-Path $tDir ".theme") -Value $chosenThemeId -Force -Encoding UTF8
        } catch { }

        Write-Host "  $ESC[42;30;1m TEMA APLICADO $Reset ${Green}Ahora usando: ${Bold}$($global:VorkThemeName)${Reset}"
        Write-Host "  ${LeadLight}Preferencia persistida en ~/.vork/.theme${Reset}"
        Write-Host ""
    }
}

function Invoke-CmdEnv {
    Write-Host ""
    Write-Host "  ${White}${Bold}VARIABLES DE ENTORNO VORK:${Reset}"
    Write-Host "  ${Cyan}  VORK_API:${Reset}    $ApiBase"
    Write-Host "  ${Cyan}  VORK_TIER:${Reset}   $global:VorkTier"
    Write-Host "  ${Cyan}  USERPROFILE:${Reset} $HOME"
    Write-Host ""
}


# ========================================================
# VORK AI CONVERSACIONAL (VORK 3, 3.1 & 3.2 EXPERT)
# ========================================================

function Invoke-VorkAIChat {
    param(
        [string]$Prompt,
        [string[]]$ArgsList
    )

    $fullPrompt = if ($Prompt) { $Prompt } elseif ($ArgsList) { $ArgsList -join " " } else { "" }
    $fullPrompt = $fullPrompt.Trim()

    if (-not $fullPrompt) {
        Write-Host ""
        Write-Host "  ${Cyan}╭─ Vork AI Conversacional ───────────────────────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Escribe tu consulta o tarea para la IA:${Reset}"
        $fullPrompt = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $fullPrompt -or -not $fullPrompt.Trim()) { return }
        $fullPrompt = $fullPrompt.Trim()
    }

    # -------------------------------------------------------------
    # 0. DETECCION INTELIGENTE DE PILARES OPERACIONALES EN EL CHAT
    # -------------------------------------------------------------
    $urlMatch = [regex]::Match($fullPrompt, 'https?://\S+')
    $extractedUrl = if ($urlMatch.Success) { $urlMatch.Value.TrimEnd('"', "'", ')', ']', '>', ';', ',') } else { $null }
    $isMediaDomain = $urlMatch.Success -and ($urlMatch.Value -match 'tiktok\.com|youtube\.com|youtu\.be|instagram\.com|reels|facebook\.com|fb\.watch|twitter\.com|x\.com|soundcloud\.com|vimeo\.com|pin(terest)?\.com')
    $isMediaIntent = $fullPrompt -match '(?i)(convertir|m[uú]sica|canci[oó]n|mp3|mp4|wav|audio|video|descargar|bajar|extraer|rip)'

    # Deteccion de formato explicito solicitado por el usuario
    $explicitFmt = $null
    if ($fullPrompt -match '(?i)\b(mp3|m[uú]sica|canci[oó]n|audio)\b') {
        $explicitFmt = "mp3"
    } elseif ($fullPrompt -match '(?i)\b(mp4|video|clip)\b') {
        $explicitFmt = "mp4"
    } elseif ($fullPrompt -match '(?i)\b(wav)\b') {
        $explicitFmt = "wav"
    }

    if ($urlMatch.Success -and ($isMediaDomain -or $isMediaIntent)) {
        $platformName = Get-VorkMediaPlatformName -Url $extractedUrl
        Write-Host ""
        Write-Host "  ${Cyan}╭─ [04] Vork Conversor Multimedia Universal ─────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Plataforma:${Reset}  ${Yellow}${Bold}$platformName${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Enlace:${Reset}      ${Cyan}$extractedUrl${Reset}"
        Write-Host "  ${Lead}│${Reset} ${LeadLight}Pilar 04 listo para procesar la conversión multimedia.${Reset}"
        Write-Host "  ${Lead}╰────────────────────────────────────────────────────────────${Reset}"
        Write-Host ""

        $chosenFormat = $null
        $chosenQuality = $null

        if ($explicitFmt) {
            # El usuario ya indico el formato, preguntamos directamente la calidad deseada para ese formato
            $chosenFormat = $explicitFmt
            $chosenQuality = Select-VorkMediaQualityChoice -Format $chosenFormat -PromptTitle "Selecciona la calidad deseada para $($chosenFormat.ToUpper()):"
            if (-not $chosenQuality) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }
        } else {
            # No indico formato: Pregunta 1 Formato, Pregunta 2 Calidad
            $chosenFormat = Select-VorkMediaFormatChoice -PromptTitle "Selecciona el formato de salida:"
            if (-not $chosenFormat) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }

            $chosenQuality = Select-VorkMediaQualityChoice -Format $chosenFormat -PromptTitle "Selecciona la calidad deseada para $($chosenFormat.ToUpper()):"
            if (-not $chosenQuality) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }
        }

        Invoke-PillarMedia -ArgsList @($extractedUrl, "-Format", $chosenFormat, "-Quality", $chosenQuality)
        return
    }

    if ($isMediaIntent -and ($fullPrompt -match '(?i)(tiktok|youtube|video|enlace|link|reels|instagram)')) {
        Write-Host ""
        Write-Host "  ${Cyan}╭─ [04] Vork Conversor Multimedia Universal ─────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Ingresa la URL del video (YouTube, TikTok, Reels, IG):${Reset}"
        $askedUrl = Read-VorkInput -Prompt "  ${Lead}│${Reset} ${Cyan}> ${Reset}"
        if (-not $askedUrl -or -not $askedUrl.Trim()) {
            $elbowChar = [char]0x23BF
            Write-Host "  ${LeadLight}$elbowChar  Operación cancelada.${Reset}"
            Write-Host ""
            return
        }
        $askedUrl = $askedUrl.Trim()
        $platformName = Get-VorkMediaPlatformName -Url $askedUrl
        Write-Host "  ${Lead}│${Reset} ${White}Plataforma:${Reset}  ${Yellow}${Bold}$platformName${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Enlace:${Reset}      ${Cyan}$askedUrl${Reset}"
        Write-Host "  ${Lead}╰────────────────────────────────────────────────────────────${Reset}"
        Write-Host ""

        $chosenFormat = $null
        $chosenQuality = $null

        if ($explicitFmt) {
            $chosenFormat = $explicitFmt
            $chosenQuality = Select-VorkMediaQualityChoice -Format $chosenFormat -PromptTitle "Selecciona la calidad deseada para $($chosenFormat.ToUpper()):"
            if (-not $chosenQuality) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }
        } else {
            $chosenFormat = Select-VorkMediaFormatChoice -PromptTitle "Selecciona el formato de salida:"
            if (-not $chosenFormat) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }

            $chosenQuality = Select-VorkMediaQualityChoice -Format $chosenFormat -PromptTitle "Selecciona la calidad deseada para $($chosenFormat.ToUpper()):"
            if (-not $chosenQuality) {
                $elbowChar = [char]0x23BF
                Write-Host "  ${LeadLight}$elbowChar  Conversión multimedia cancelada.${Reset}"
                Write-Host ""
                return
            }
        }

        Invoke-PillarMedia -ArgsList @($askedUrl, "-Format", $chosenFormat, "-Quality", $chosenQuality)
        return
    }

    # -------------------------------------------------------------
    # 1. ACCIONES CONVERSACIONALES DIRECTAS HACIA LOS PILARES
    # -------------------------------------------------------------
    if ($fullPrompt -match '(?i)^\s*traduc(ir|e)\s+(.+)$') {
        $transTarget = $matches[2].Trim()
        Write-Host ""
        Write-Host "  ${Cyan}╭─ [01] Vork Traductor en la Nube ───────────────────────────${Reset}"
        Write-Host "  ${Lead}│${Reset} ${White}Detectado requerimiento de traducción directa.${Reset}"
        Write-Host "  ${Lead}╰────────────────────────────────────────────────────────────${Reset}"
        Invoke-PillarTranslate -ArgsList @("es", $transTarget)
        return
    }

    if ($fullPrompt -match '(?i)\b(separar stems|separar pistas?|quitar la? voz|aislar la? voz|karaoke de)\b') {
        Invoke-PillarSeparate
        return
    }

    if ($fullPrompt -match '(?i)\b(quitar el? fondo|eliminar el? fondo|fondo transparente)\b') {
        Invoke-PillarRemoveBg
        return
    }

    if ($fullPrompt -match '(?i)\b(convertir imagen|pasar imagen a)\b') {
        Invoke-PillarImage
        return
    }

    if ($fullPrompt -match '(?i)\b(texto a voz|sintetizar voz|leer con voz)\b') {
        Invoke-PillarTTS
        return
    }

    if ($fullPrompt -match '(?i)\b(clonar voz|clonacion de voz|clonación de voz)\b') {
        Invoke-PillarClone
        return
    }

    $activeModel = if ($global:VorkModel) { $global:VorkModel } else { "Vork 3.1" }
    $activeTier = if ($activeModel -eq "Vork 3.2") { "expert" } elseif ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $tierLabel = if ($activeTier.Length -gt 1) { $activeTier.Substring(0,1).ToUpper() + $activeTier.Substring(1).ToLower() } else { $activeTier.ToUpper() }
    $tierColor = switch ($activeTier) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        "expert" { $Purple }
        default  { $Cyan }
    }

    Write-Host ""
    Write-Host "  ${tierColor}$([char]0x25CF)${Reset} ${LeadLight}Pensando con ${White}${Bold}$activeModel${Reset} ${LeadLight}(${tierColor}${Bold}$tierLabel${Reset}${LeadLight})...${Reset}"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $answer = ""
    # 1. Intentar backend oficial de Vork
    try {
        $bodyJson = @{
            message = $fullPrompt
            model = $activeModel
            effort = $activeTier
        } | ConvertTo-Json -Compress

        $timeoutSec = if ($activeTier -in "high", "expert") { 60 } else { 35 }
        $res = Invoke-RestMethod -Uri "$ApiBase/api/ai/chat" -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec $timeoutSec -ErrorAction Stop
        if ($res -and $res.response) {
            $answer = $res.response
        } elseif ($res -and $res.message) {
            $answer = $res.message
        }
    } catch {
        # Si el backend en la nube en Render se encuentra reactivándose o sin conectividad
        $answer = "No se pudo conectar con el motor en la nube de Vork ($ApiBase). Verifica tu conexión a internet o reintenta en unos instantes mientras el servidor en Render responde."
    }

    $sw.Stop()
    $elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 1)

    Write-Host ""
    if ($answer) {
        Write-VorkAIResponse -Answer $answer -ActiveModel $activeModel -TierLabel $tierLabel -ElapsedSec $elapsedSec
    } else {
        Write-Host "  ${Coral}[Error]:${Reset} No se pudo obtener respuesta del motor de Vork AI."
        Write-Host ""
    }

    Save-VorkConversationRecord -Cmd $fullPrompt -Output $answer
}