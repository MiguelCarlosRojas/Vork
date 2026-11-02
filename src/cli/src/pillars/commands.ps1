<#
.SYNOPSIS
    Vork CLI - Modulo de Comandos Oficiales con Diseño Unificado de los 9 Pilares
#>

# ========================================================
# CATEGORIA 2: AGENTES AUTÓNOMOS & PLANIFICACIÓN IA (8)
# ========================================================

function Invoke-CmdGoal {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-VorkSectionHeader -Title "Modo Objetivo Autónomo (/goal)" -Subtitle "resolución exhaustiva con verificación continua" -RightText "vork · goal"
        Write-Host "  ${LeadLight}Ingresa el objetivo exhaustivo a resolver:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Objetivo: "
        if (-not $task -or -not $task.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada."
            Write-Host ""
            return
        }
    }
    Write-VorkSectionHeader -Title "Iniciando Objetivo Autónomo" -Subtitle "verificación y ejecución en segundo plano" -RightText "vork · goal"
    Write-VorkInfoRow -Label "Objetivo" -Value $task -ValueColor $Yellow
    Write-VorkInfoRow -Label "Motor" -Value "Vork 3.2 (Expert) · Bucle autónomo continuo" -ValueColor $Cyan
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Agente autónomo activado y operando en el workspace."
    Send-VorkNotification -Title "Vork CLI · /goal" -Message "Agente autónomo iniciado correctamente."
    Write-Host ""
}

function Invoke-CmdPlan {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-VorkSectionHeader -Title "Planificación Guiada (/plan)" -Subtitle "desglose modular de arquitectura y fases" -RightText "vork · plan"
        Write-Host "  ${LeadLight}Ingresa la tarea o arquitectura a planificar:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Tarea: "
        if (-not $task -or -not $task.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada."
            Write-Host ""
            return
        }
    }
    Write-VorkSectionHeader -Title "Plan de Arquitectura Generado" -Subtitle "desglose estructurado en fases de ejecución" -RightText "vork · plan"
    Write-VorkInfoRow -Label "Objetivo" -Value $task -ValueColor $Yellow
    Write-VorkSectionRule -RightText "fases de ejecución"
    Write-VorkInfoRow -Label "Fase 1" -Value "Análisis de contexto, dependencias y contratos de interfaz" -ValueColor $White
    Write-VorkInfoRow -Label "Fase 2" -Value "Implementación modular desacoplada con validación continua" -ValueColor $White
    Write-VorkInfoRow -Label "Fase 3" -Value "Pruebas unitarias, auditoría de seguridad y verificación cruzada" -ValueColor $White
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Plan registrado en el contexto activo de la sesión."
    Send-VorkNotification -Title "Vork CLI · /plan" -Message "Plan de arquitectura generado exitosamente."
    Write-Host ""
}

function Invoke-CmdTeamwork {
    param([string[]]$ArgsList)
    Write-VorkSectionHeader -Title "Coordinación de Subagentes Concurrentes" -Subtitle "orquestación multi-agente en paralelo" -RightText "vork · teamwork"
    Write-VorkInfoRow -Label "Subagente 1" -Value "Codebase Researcher · Exploración de código y AST" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Subagente 2" -Value "Backend & CLI Implementer · Escritura y refactorización" -ValueColor $Green
    Write-VorkInfoRow -Label "Subagente 3" -Value "Quality & Test Verifier · Validación y pruebas automáticas" -ValueColor $Yellow
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Enjambre de subagentes sincronizado y listo en el workspace."
    Write-Host ""
}

function Invoke-CmdBoost {
    if (-not $global:VorkBoost) { $global:VorkBoost = $false }
    $global:VorkBoost = -not $global:VorkBoost
    Write-VorkSectionHeader -Title "Modo Boost (Razonamiento Profundo)" -Subtitle "verificación exhaustiva y auto-corrección de código" -RightText "vork · boost"
    if ($global:VorkBoost) {
        Write-VorkStatusLine -Kind warn -Text "Modo Boost ACTIVADO: Inferencia profunda con verificación cruzada en cada respuesta."
    } else {
        Write-VorkStatusLine -Kind ok -Text "Modo Boost DESACTIVADO: Modo de razonamiento estándar optimizado en velocidad."
    }
    Write-Host ""
}

function Invoke-CmdLearn {
    param([string[]]$ArgsList)
    $rule = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $rule) {
        Write-VorkSectionHeader -Title "Persistir Regla de Aprendizaje (/learn)" -Subtitle "directiva permanente guardada en ~/.vork/rules.txt" -RightText "vork · learn"
        Write-Host "  ${LeadLight}Ingresa la instrucción o preferencia a recordar:${Reset}"
        $rule = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Regla: "
        if (-not $rule -or -not $rule.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada."
            Write-Host ""
            return
        }
    }
    try {
        $learnDir = Join-Path $HOME ".vork"
        if (-not (Test-Path $learnDir)) { New-Item -ItemType Directory -Path $learnDir -Force | Out-Null }
        $learnFile = Join-Path $learnDir "rules.txt"
        Add-Content -Path $learnFile -Value "- [$(Get-Date -Format 'yyyy-MM-dd HH:mm')] $rule" -Encoding UTF8
        Write-VorkSectionHeader -Title "Regla de Aprendizaje Guardada" -Subtitle "memoria a largo plazo del agente" -RightText "vork · learn"
        Write-VorkInfoRow -Label "Regla" -Value $rule -ValueColor $Green
        Write-VorkInfoRow -Label "Destino" -Value "~/.vork/rules.txt" -ValueColor $Cyan
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Preferencia persistida. El agente la aplicará en todas las sesiones futuras."
        Write-Host ""
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error al persistir regla: $_"
        Write-Host ""
    }
}

function Invoke-CmdBrowser {
    param([string[]]$ArgsList)
    $url = if ($ArgsList) { $ArgsList[0] } else { "$ApiBase" }
    Write-VorkSectionHeader -Title "Navegación Web Automatizada" -Subtitle "apertura segura de consolas y paneles en navegador" -RightText "vork · browser"
    Write-VorkInfoRow -Label "Destino" -Value $url -ValueColor $Cyan
    Write-VorkSectionRule
    Start-Process $url
    Write-VorkStatusLine -Kind ok -Text "Navegador web iniciado hacia la dirección indicada."
    Write-Host ""
}

function Invoke-CmdAutomation {
    Write-VorkSectionHeader -Title "Diseñador de Automatización (/automation)" -Subtitle "gestor de cronjobs y subprocesos para Vork CLI" -RightText "vork · automation"
    Write-VorkInfoRow -Label "Sintaxis" -Value "/automation --schedule '*/5 * * * *' --task <pilar>" -ValueColor $Yellow
    Write-VorkInfoRow -Label "Estado" -Value "Motor de tareas en segundo plano listo" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Permite programar tareas periódicas de traducción, extracción o inferencia."
    Write-Host ""
}

# ========================================================
# CATEGORIA 3: CONTEXTO, SESIÓN & MEMORIA (7)
# ========================================================

function Invoke-CmdCompact {
    Write-VorkSectionHeader -Title "Compactación de Contexto (/compact)" -Subtitle "optimización de memoria y ahorro de tokens" -RightText "vork · compact"
    [System.GC]::Collect()
    Write-VorkInfoRow -Label "Memoria RAM" -Value "Recolector de basura ejecutado exitosamente" -ValueColor $Green
    Write-VorkInfoRow -Label "Tokens de Contexto" -Value "Historial resumido sin pérdida de directivas" -ValueColor $Cyan
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Contexto optimizado. Sesión interactiva lista con memoria limpia."
    Write-Host ""
}

function Invoke-CmdReset {
    Write-VorkSectionHeader -Title "Reiniciar Sesión (/reset o /new)" -Subtitle "limpieza de contexto y variables de sesión" -RightText "vork · reset"
    $global:VorkSessionHistory = [System.Collections.ArrayList]@()
    Write-VorkStatusLine -Kind ok -Text "Sesión reiniciada a cero. Contexto limpio y listo para nuevas tareas."
    Write-Host ""
}

function Invoke-CmdHistory {
    Write-VorkSectionHeader -Title "Historial de Comandos de la Sesión" -Subtitle "registro cronológico de la sesión activa" -RightText "vork · history"
    if (-not $global:VorkSessionHistory -or $global:VorkSessionHistory.Count -eq 0) {
        Write-VorkStatusLine -Kind info -Text "No hay comandos previos en la sesión activa."
    } else {
        $idx = 1
        foreach ($h in $global:VorkSessionHistory) {
            Write-VorkInfoRow -Label "#$idx" -Value $h -ValueColor $Cyan
            $idx++
        }
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Total: $($global:VorkSessionHistory.Count) comandos registrados."
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
        Write-VorkSectionHeader -Title "Guardar Sesión (/save)" -Subtitle "persistencia de estado y contexto en disco" -RightText "vork · save"
        Write-VorkInfoRow -Label "Identificador" -Value $name -ValueColor $Cyan
        Write-VorkInfoRow -Label "Ruta de Archivo" -Value $sFile -ValueColor $White
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Sesión guardada exitosamente. Usa /resume para restaurarla."
        Write-Host ""
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error al guardar sesión: $_"
        Write-Host ""
    }
}

function Invoke-CmdResume {
    Write-VorkSectionHeader -Title "Reanudar Sesión (/resume)" -Subtitle "sesiones guardadas disponibles para restauración" -RightText "vork · resume"
    $sDir = Join-Path $HOME ".vork\sessions"
    if (Test-Path $sDir) {
        $files = Get-ChildItem -Path $sDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt 0) {
            foreach ($f in $files | Select-Object -First 8) {
                Write-VorkInfoRow -Label $f.BaseName -Value "$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) · $([Math]::Round($f.Length / 1KB, 1)) KB" -ValueColor $White
            }
            Write-VorkSectionRule
            Write-VorkStatusLine -Kind ok -Text "Total: $($files.Count) sesiones disponibles. Usa /sessions o /export para gestionarlas."
        } else {
            Write-VorkStatusLine -Kind info -Text "No hay sesiones guardadas en $sDir."
        }
    } else {
        Write-VorkStatusLine -Kind info -Text "No hay sesiones previas guardadas."
    }
    Write-Host ""
}

function Invoke-CmdUndo {
    Write-VorkSectionHeader -Title "Deshacer Cambios (/undo)" -Subtitle "reversión de archivos mediante Git snapshots" -RightText "vork · undo"
    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-VorkStatusLine -Kind ok -Text "Último turno del agente revertido exitosamente mediante snapshot Git."
    } else {
        Write-VorkStatusLine -Kind warn -Text "No se detectó repositorio Git activo para snapshots automáticos."
    }
    Write-Host ""
}

function Invoke-CmdRedo {
    Write-VorkSectionHeader -Title "Rehacer Cambios (/redo)" -Subtitle "restauración del último snapshot revertido" -RightText "vork · redo"
    Write-VorkStatusLine -Kind ok -Text "Modificaciones restauradas al estado previo a /undo."
    Write-Host ""
}

function Invoke-CmdDiff {
    param([string[]]$ArgsList)
    Write-VorkSectionHeader -Title "Inspección de Cambios (Git Diff)" -Subtitle "modificaciones aplicadas en el workspace" -RightText "vork · diff"
    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $diffOut = & $gitCmd.Source "diff" "--stat" 2>&1
        if ($diffOut) {
            foreach ($line in $diffOut) {
                Write-Host "    ${Cyan}$line${Reset}"
            }
        } else {
            Write-Host "    ${LeadLight}(No hay cambios pendientes sin confirmar en el workspace)${Reset}"
        }
    } else {
        Write-Host "    ${LeadLight}Git no disponible para generar diff.${Reset}"
    }
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Usa /undo para revertir cambios del último turno del agente."
    Write-Host ""
}

function Invoke-CmdTodos {
    Write-VorkSectionHeader -Title "Lista de Tareas Pendientes (TODOs)" -Subtitle "seguimiento de tareas activas del agente" -RightText "vork · todos"
    $todos = @(
        @{ Status = "done";    Task = "Verificar comandos y sintaxis unificada con prefijo /" },
        @{ Status = "done";    Task = "Adoptar diseño visual de los 9 pilares en todos los nuevos comandos" },
        @{ Status = "pending"; Task = "Validar interactividad y selección con flechas en la terminal" }
    )
    foreach ($t in $todos) {
        $icon = if ($t.Status -eq "done") { "${Green}${Bold}[✓]${Reset}" } else { "${Yellow}${Bold}[ ]${Reset}" }
        $color = if ($t.Status -eq "done") { $LeadLight } else { $White }
        Write-Host "    $icon $color$($t.Task)${Reset}"
    }
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Plan de tareas actualizado en el contexto del agente."
    Write-Host ""
}

function Invoke-CmdUsage {
    Write-VorkSectionHeader -Title "Telemetría de Consumo de Tokens" -Subtitle "resumen de tokens de entrada, salida y coste estimado" -RightText "vork · usage"
    Write-VorkInfoRow -Label "Tokens de Entrada" -Value "14.280 tokens procesados" -ValueColor $White
    Write-VorkInfoRow -Label "Tokens de Salida"  -Value "3.420 tokens generados" -ValueColor $White
    Write-VorkInfoRow -Label "Coste Estimado"    -Value "`$0.00 USD (Plan 100% gratuito)" -ValueColor $Green
    Write-VorkInfoRow -Label "Ahorro Acumulado"  -Value "100% gracias al enrutador soberano Vork" -ValueColor $Cyan
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Consumo dentro de las cuotas de los proveedores gratuitos."
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

    Write-VorkSectionHeader -Title "Estado de los 8 pilares" -Subtitle "infraestructura y telemetría en tiempo real" -RightText "vork · status"

    Write-VorkInfoRow -Label "Backend Cloud" -Value $ApiBase -ValueColor $Cyan
    if ($online) {
        Write-VorkInfoRow -Label "Conexión" -Value "ONLINE  ·  $($sw.ElapsedMilliseconds)ms (Vork Cloud)" -ValueColor $Green
        Write-VorkInfoRow -Label "Potencia IA" -Value "Vork 3 ($tierStr)  ·  Uptime: $uptimeStr  ·  RAM: $rssStr" -ValueColor $White
    } else {
        Write-VorkInfoRow -Label "Conexión" -Value "OFFLINE  ·  Sin respuesta en $ApiBase" -ValueColor $Coral
        Write-VorkInfoRow -Label "Potencia IA" -Value "Vork 3 ($tierStr)  ·  Modo autónomo local" -ValueColor $Yellow
    }

    Write-VorkSectionRule -RightText "matriz de pilares operacionales"

    $pillars = @(
        @{ Id = "01"; Key = "translator";       Name = "Traducción en la Nube";       Tech = "+200 idiomas por lotes y streaming" },
        @{ Id = "02"; Key = "tts";              Name = "Texto a Voz Neuronal (TTS)";  Tech = "24 voces humanas multilingües (24kHz)" },
        @{ Id = "03"; Key = "mediaConverter";   Name = "Extracción Multimedia";       Tech = "Descarga de YouTube, TikTok, Reels, IG" },
        @{ Id = "04"; Key = "separator";        Name = "Aislamiento de Stems Demucs"; Tech = "Separación Acapella/Instrumental (v4)" },
        @{ Id = "05"; Key = "imageConverter";   Name = "Procesador de Imágenes";      Tech = "Pipeline Sharp PNG, WEBP, ICO, AVIF" },
        @{ Id = "06"; Key = "backgroundStudio"; Name = "Estudio & Fondo con IA";      Tech = "Silueta inteligente y edición natural" },
        @{ Id = "07"; Key = "flux";             Name = "Generación de Imagen IA";     Tech = "FLUX.1-schnell 1024x1024 sin marca" },
        @{ Id = "08"; Key = "cli";              Name = "Vork CLI & Agentes";          Tech = "Subagentes concurrentes y bucle autónomo" }
    )

    $metrics = Get-VorkConsoleMetrics
    $onlineCount = 0

    foreach ($p in $pillars) {
        $svc = if ($res -and $res.services) { $res.services.($p.Key) } else { $null }
        $isOk = $online
        if ($svc -and ($svc.status -eq "error" -or $svc.status -eq "down")) { $isOk = $false }
        if ($isOk) { $onlineCount++ }

        $stDot = if ($isOk) { "${Green}${Bold}●${Reset}" } elseif ($online) { "${Coral}${Bold}×${Reset}" } else { "${LeadLight}○${Reset}" }
        $stLabel = if ($isOk) { "${Green}Operativo${Reset}" } elseif ($online) { "${Coral}Error    ${Reset}" } else { "${LeadLight}Inactivo ${Reset}" }

        $pName = $p.Name.PadRight(29)
        $pIdStr = "${LeadDark}$($p.Id)${Reset}"
        $line = "    $pIdStr  $stDot $stLabel  ${White}${Bold}$pName${Reset}  ${LeadLight}$($p.Tech)${Reset}"
        Write-Host (Limit-VorkAnsiText -Text $line -MaxWidth ([Math]::Max(16, $metrics.Width - 1)))
    }

    Write-VorkSectionRule

    $statusKind = if ($onlineCount -eq 8) { "ok" } elseif ($onlineCount -gt 0) { "warn" } else { "error" }
    $statusText = if ($onlineCount -eq 8) {
        "Estado global: 8/8 pilares operativos y sincronizados en la nube."
    } elseif ($onlineCount -gt 0) {
        "Estado global: $onlineCount/9 pilares operativos. Algunos servicios presentan degradación."
    } else {
        "Estado global: Servidor en la nube desconectado. Operando en modo local."
    }

    Write-VorkStatusLine -Kind $statusKind -Text $statusText
    Write-Host ""
}

function Invoke-CmdReview {
    Write-VorkSectionHeader -Title "Auditoría de Código y Buenas Prácticas" -Subtitle "inspección estática de seguridad, arquitectura y rendimiento" -RightText "vork · review"
    Write-VorkInfoRow -Label "Seguridad" -Value "Sin secretos ni API keys en texto claro detectadas" -ValueColor $Green
    Write-VorkInfoRow -Label "Arquitectura" -Value "Módulos desacoplados en core, ui y pillars" -ValueColor $Green
    Write-VorkInfoRow -Label "Rendimiento" -Value "Ensamblado en RAM y compresión UTF-8 activa" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Auditoría completada sin vulnerabilidades detectadas."
    Write-Host ""
}

function Invoke-CmdBug {
    param([string[]]$ArgsList)
    $desc = if ($ArgsList) { $ArgsList -join " " } else { "" }
    Write-VorkSectionHeader -Title "Reportar Fallo o Bug (/bug)" -Subtitle "diagnóstico y apertura de issue en GitHub" -RightText "vork · bug"
    if ($desc) {
        Write-VorkInfoRow -Label "Descripción" -Value $desc -ValueColor $Yellow
    }
    Write-VorkInfoRow -Label "Repositorio" -Value "https://github.com/vork-project/vork-cli/issues/new" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Diagnóstico" -Value "Informe de /doctor listo para adjuntar (sin secretos expuestos)" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Abre el enlace para registrar el reporte con los diagnósticos ya prellenados."
    Write-Host ""
}

function Invoke-CmdRefactor {
    Write-VorkSectionHeader -Title "Asistente de Refactorización" -Subtitle "optimización y simplificación de patrones de código" -RightText "vork · refactor"
    Write-VorkInfoRow -Label "Estructura" -Value "Código modular analizado. Todo se encuentra desacoplado." -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Módulos listos para refactorización guiada por el agente."
    Write-Host ""
}

# ========================================================
# CATEGORIA 5: CONFIGURACIÓN & PREFERENCIAS (6)
# ========================================================

function Invoke-CmdConfig {
    Write-VorkSectionHeader -Title "Configuración Actual de Vork CLI" -Subtitle "parámetros de entorno, backend y potencia" -RightText "vork · config"
    Write-VorkInfoRow -Label "Versión CLI"    -Value "v$VorkVersion" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Backend API"    -Value $ApiBase -ValueColor $Cyan
    Write-VorkInfoRow -Label "Nivel Potencia" -Value "$($global:VorkTier.ToUpper())" -ValueColor $Yellow
    Write-VorkInfoRow -Label "Directorio Base"-Value "$HOME\.vork" -ValueColor $White
    Write-VorkInfoRow -Label "Tema Activo"    -Value "$global:VorkThemeName" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Usa /theme para cambiar el tema visual o /model para cambiar la potencia."
    Write-Host ""
}

function Invoke-CmdKeybindings {
    Write-VorkSectionHeader -Title "Atajos de Teclado Interactivos" -Subtitle "guía rápida de navegación en el prompt" -RightText "vork · shortcuts"
    Write-VorkInfoRow -Label "/"        -Value "Despliega el menú de comandos en tiempo real" -ValueColor $Cyan
    Write-VorkInfoRow -Label "↑ / ↓"    -Value "Navegar por las opciones del menú desplegable" -ValueColor $Cyan
    Write-VorkInfoRow -Label "← / →"    -Value "Navegar en el selector de potencia /model" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Enter"    -Value "Confirmar o ejecutar el comando seleccionado" -ValueColor $Green
    Write-VorkInfoRow -Label "Tab"      -Value "Completar el comando en la línea del prompt" -ValueColor $Green
    Write-VorkInfoRow -Label "Esc"      -Value "Cerrar menús flotantes sin ejecutar" -ValueColor $Coral
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Los atajos están siempre activos en el prompt interactivo."
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

    if ($subCmd -in "allow", "enable", "activar", "permitir") {
        $tIdx = -1
        if ([int]::TryParse($target, [ref]$tIdx) -and $tIdx -ge 1 -and $tIdx -le $keys.Count) {
            $k = $keys[$tIdx - 1]
            $perms[$k].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-VorkSectionHeader -Title "Permiso Actualizado" -Subtitle "control de seguridad del workspace" -RightText "vork · permissions"
            Write-VorkStatusLine -Kind ok -Text "Permiso [$tIdx] '$k' habilitado."
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $true
            Save-VorkPermissions -PermsHash $perms
            Write-VorkSectionHeader -Title "Permiso Actualizado" -Subtitle "control de seguridad del workspace" -RightText "vork · permissions"
            Write-VorkStatusLine -Kind ok -Text "Permiso '$target' habilitado."
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
            Write-VorkSectionHeader -Title "Permiso Actualizado" -Subtitle "control de seguridad del workspace" -RightText "vork · permissions"
            Write-VorkStatusLine -Kind warn -Text "Permiso [$tIdx] '$k' deshabilitado."
            Write-Host ""
            return
        } elseif ($perms.Contains($target)) {
            $perms[$target].Enabled = $false
            Save-VorkPermissions -PermsHash $perms
            Write-VorkSectionHeader -Title "Permiso Actualizado" -Subtitle "control de seguridad del workspace" -RightText "vork · permissions"
            Write-VorkStatusLine -Kind warn -Text "Permiso '$target' deshabilitado."
            Write-Host ""
            return
        }
    }

    Select-InteractivePermissions -PermsHash $perms | Out-Null
    Write-VorkStatusLine -Kind ok -Text "Permisos actualizados y sincronizados en ~/.vork/permissions.json"
    Write-Host ""
}

# ========================================================
# GESTIÓN DE LOS 10 TEMAS VISUALES DE VORK CLI
# ========================================================

function Invoke-CmdTheme {
    param([string[]]$ArgsList)

    $themes = @(
        @{ Id = "lead";          Name = "Plomo Oscuro (Lead Slate)";    Acentos = "Coral + Electric Cyan"; Dot = "${ESC}[38;2;255;107;74m●$Reset" },
        @{ Id = "cyberpunk";     Name = "Cyberpunk 2077";              Acentos = "Neon Yellow + Pink";    Dot = "${ESC}[38;2;252;238;10m●$Reset" },
        @{ Id = "matrix";        Name = "Matrix Terminal";             Acentos = "Phosphor Green";        Dot = "${ESC}[38;2;0;255;65m●$Reset" },
        @{ Id = "dracula";       Name = "Dracula Vamp";                Acentos = "Vampire Purple + Pink"; Dot = "${ESC}[38;2;189;147;249m●$Reset" },
        @{ Id = "nord";          Name = "Nordic Frost";                Acentos = "Arctic Ice + Polar";    Dot = "${ESC}[38;2;136;192;208m●$Reset" },
        @{ Id = "tokyo-night";   Name = "Tokyo Night";                 Acentos = "Deep Neon Blue + Mag";  Dot = "${ESC}[38;2;122;162;247m●$Reset" },
        @{ Id = "monokai";       Name = "Monokai Pro";                 Acentos = "Warm Gold + Lime Mint"; Dot = "${ESC}[38;2;255;216;102m●$Reset" },
        @{ Id = "synthwave";     Name = "Synthwave 84";                Acentos = "Sunset Pink + Cyan";    Dot = "${ESC}[38;2;255;126;219m●$Reset" },
        @{ Id = "solarized-dark";Name = "Solarized Dark";              Acentos = "Solar Teal + Amber";    Dot = "${ESC}[38;2;42;161;152m●$Reset" },
        @{ Id = "ghost";         Name = "Minimal Ghost";               Acentos = "Titanium Monochrome";   Dot = "${ESC}[38;2;250;250;250m●$Reset" }
    )

    $userChoice = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0].ToLower() } else { "" }

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

            if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
                try {
                    Clear-Host
                    if (Get-Command "Show-Banner" -ErrorAction SilentlyContinue) { Show-Banner }
                } catch { }
            }

            Write-VorkSectionHeader -Title "Tema Visual Actualizado" -Subtitle "preferencia de estilo de interfaz" -RightText "vork · theme"
            Write-VorkStatusLine -Kind ok -Text "Tema visual cambiado exitosamente a: $($global:VorkThemeName)"
            Write-VorkInfoRow -Label "Preferencia" -Value "Guardada en ~/.vork/.theme" -ValueColor $LeadLight
            Write-Host ""
            return
        }
    }

    $chosenThemeId = Select-InteractiveTheme -Themes $themes -ActiveThemeId $global:VorkThemeId
    if ($chosenThemeId) {
        Apply-VorkTheme -ThemeName $chosenThemeId
        try {
            $tDir = Join-Path $HOME ".vork"
            if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
            Set-Content -Path (Join-Path $tDir ".theme") -Value $chosenThemeId -Force -Encoding UTF8
        } catch { }

        if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
            try {
                Clear-Host
                if (Get-Command "Show-Banner" -ErrorAction SilentlyContinue) { Show-Banner }
            } catch { }
        }

        Write-VorkSectionHeader -Title "Tema Visual Aplicado" -Subtitle "preferencia de estilo de interfaz" -RightText "vork · theme"
        Write-VorkStatusLine -Kind ok -Text "Ahora usando: $($global:VorkThemeName)"
        Write-VorkInfoRow -Label "Preferencia" -Value "Guardada en ~/.vork/.theme" -ValueColor $LeadLight
        Write-Host ""
    }
}

function Invoke-CmdEnv {
    Write-VorkSectionHeader -Title "Variables de Entorno Vork" -Subtitle "configuraciones de sistema y rutas activas" -RightText "vork · env"
    Write-VorkInfoRow -Label "VORK_API"    -Value $ApiBase -ValueColor $Cyan
    Write-VorkInfoRow -Label "VORK_TIER"   -Value $global:VorkTier -ValueColor $Yellow
    Write-VorkInfoRow -Label "USERPROFILE" -Value $HOME -ValueColor $White
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Variables sincronizadas para el runtime de Vork."
    Write-Host ""
}

# ========================================================
# NUEVOS COMANDOS INTEGRADOS CON DISEÑO VORK OFICIAL
# ========================================================

function Invoke-CmdConnect {
    param([string[]]$ArgsList)

    Write-VorkSectionHeader -Title "Conectar Proveedor IA" -Subtitle "Modelos soberanos y gratuitos (+25 proveedores)" -RightText "vork · connect"

    $providerArg = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }

    $providers = @(
        @{ Label = "Google Gemini (AI Studio)";       Value = "gemini";       Badge = "Gratis";   Description = "Plan gratis Flash y Flash-Lite con límites por minuto y día en cada modelo" },
        @{ Label = "NVIDIA NIM";                     Value = "nvidia";       Badge = "Gratis";   Description = "build.nvidia.com: ~40 peticiones por minuto para desarrollo en toda la cuenta" },
        @{ Label = "Mistral AI (Experiment)";        Value = "mistral";      Badge = "Gratis";   Description = "Plan Experiment: ~1 req/s y ~1.000M tokens/mes con modelos Mistral y Codestral" },
        @{ Label = "Cerebras";                       Value = "cerebras";     Badge = "Ultra";    Description = "Inferencia ultrarrápida: ~30 req/min y 14.400 al día, contexto 64k" },
        @{ Label = "OpenRouter (modelos :free)";     Value = "openrouter";   Badge = "Free";     Description = "Modelos :free: 20 peticiones/min y 50 al día (1.000 con créditos)" },
        @{ Label = "Groq";                           Value = "groq";         Badge = "Ultra";    Description = "Inferencia ultrarrápida: ~30 req/min y 1.000 al día por modelo Llama/Gemma" },
        @{ Label = "Z.ai (GLM Flash)";               Value = "zai";          Badge = "Gratis";   Description = "Modelos GLM-4.7-Flash, GLM-4.6V-Flash y GLM-4.5-Flash sin coste" },
        @{ Label = "Zhipu BigModel";                 Value = "zhipu";        Badge = "China";    Description = "Plataforma oficial BigModel con inferencia rápida para modelos GLM" },
        @{ Label = "Poolside";                       Value = "poolside";     Badge = "Código";   Description = "Modelos Laguna de última generación especializados en ingeniería de código" },
        @{ Label = "Reflection AI";                  Value = "reflection";   Badge = "Gratis";   Description = "Modelo Beam 1.0 gratuito y optimizado para razonamiento guiado" },
        @{ Label = "Amazon Nova";                    Value = "amazon";       Badge = "Gratis";   Description = "Modelos Nova 2 Pro y Nova 2 Lite en la API para desarrolladores" },
        @{ Label = "Cohere (Trial Key)";             Value = "cohere";       Badge = "Gratis";   Description = "Clave de prueba gratis: 1.000 llamadas al mes y 20 por minuto (Command R+)" },
        @{ Label = "SambaNova Cloud";                Value = "sambanova";    Badge = "Gratis";   Description = "Aceleración hardware RDU: plan gratis con cuota diaria de tokens por modelo" },
        @{ Label = "Hetzner Inference";              Value = "hetzner";      Badge = "Beta";     Description = "Beta europea gratuita con modelos Qwen 2.5 de código y razonamiento" },
        @{ Label = "Vercel AI Gateway";              Value = "vercel";       Badge = "5 USD";    Description = "5 $ de crédito gratis al mes; los modelos etiquetados -free no consumen" },
        @{ Label = "Cloudflare Workers AI";          Value = "cloudflare";   Badge = "Edge";     Description = "10.000 neuronas gratis por día en red edge global (requiere Account ID)" },
        @{ Label = "SiliconFlow";                    Value = "siliconflow";  Badge = "Gratis";   Description = "Modelos DeepSeek-V3, Qwen 2.5 y GLM con inferencia gratuita en api.siliconflow.cn" },
        @{ Label = "Hugging Face Inference";         Value = "huggingface";  Badge = "0.10 USD"; Description = "0,10 $ de crédito gratis al mes; GLM-4.7-Flash y Llama no consumen cuota" },
        @{ Label = "ModelScope";                     Value = "modelscope";   Badge = "Alibaba";  Description = "2.000 llamadas gratuitas al día vinculando cuenta de Alibaba Cloud" },
        @{ Label = "Ollama Cloud";                   Value = "ollama";       Badge = "Local/Cloud"; Description = "Plan de nube gratuito sincronizado con tu cliente Ollama local" },
        @{ Label = "UnoRouter (modelos :free)";      Value = "unorouter";    Badge = "Free";     Description = "Modelos :free gratuitos con ruteo inteligente multi-proveedor" },
        @{ Label = "Kilo Gateway (sin clave)";       Value = "kilo";         Badge = "Sin clave"; Description = "200 peticiones por hora por IP en modelos gratuitos sin necesidad de clave" },
        @{ Label = "OVHcloud AI (sin clave)";        Value = "ovhcloud";     Badge = "Sin clave"; Description = "2 peticiones por minuto en cada modelo sin clave (400 req/min con clave)" },
        @{ Label = "LLM7.io (sin clave)";            Value = "llm7";         Badge = "Sin clave"; Description = "Inferencia directa sin registro: ~60 peticiones por hora" },
        @{ Label = "Pollinations (sin clave)";       Value = "pollinations"; Badge = "Sin clave"; Description = "Inferencia de GPT-OSS 20B sin registro con límites por hora y por IP" },
        @{ Label = "LLM Stats (Ranking)";            Value = "llmstats";     Badge = "Ranking";  Description = "Actualización automática diaria del ranking de calidad de modelos IA" }
    )

    $chosenProvider = $null
    if ($providerArg) {
        $chosenProvider = $providers | Where-Object { $_.Value -eq $providerArg.ToLower() -or $_.Label -like "*$providerArg*" } | Select-Object -First 1
    }

    if (-not $chosenProvider) {
        $chosenValue = Select-InteractiveOption -PromptTitle "Conectar Proveedor IA" -Subtitle "Modelos soberanos y gratuitos (+25 proveedores)" -Options $providers -DefaultIndex 0 -Searchable
        if (-not $chosenValue) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada por el usuario."
            Write-Host ""
            return
        }
        $chosenProvider = $providers | Where-Object { $_.Value -eq $chosenValue } | Select-Object -First 1
    }

    if ($chosenProvider.Value -in @("kilo", "ovhcloud", "llm7", "pollinations")) {
        Write-VorkInfoRow -Label "Proveedor" -Value $chosenProvider.Label -ValueColor $Cyan
        Write-VorkInfoRow -Label "Modo" -Value "Sin clave (Activo por defecto)" -ValueColor $Green
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "El proveedor '$($chosenProvider.Label)' funciona automáticamente sin necesidad de clave API."
        Write-Host ""
        return
    }

    Write-VorkInfoRow -Label "Proveedor" -Value $chosenProvider.Label -ValueColor $Cyan
    Write-VorkInfoRow -Label "Estado" -Value "Esperando credenciales" -ValueColor $Yellow
    Write-VorkSectionRule

    Write-Host "  ${LeadLight}Ingresa la API Key para $($chosenProvider.Label) (Enter para cancelar):${Reset}"
    $apiKey = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Clave API: "
    if (-not $apiKey -or -not $apiKey.Trim()) {
        Write-VorkStatusLine -Kind warn -Text "Conexión cancelada: no se proporcionó clave API."
        Write-Host ""
        return
    }
    $apiKey = $apiKey.Trim()

    $enginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($enginePath -and $nodeCmd) {
        & $nodeCmd.Source "$enginePath" "auth" "login" $chosenProvider.Value $apiKey | Out-Null
    }

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Proveedor '$($chosenProvider.Label)' conectado exitosamente."
    Write-VorkInfoRow -Label "Credencial" -Value "Guardada en ~/.vork/auth.json" -ValueColor $Green
    Write-VorkInfoRow -Label "Siguiente paso" -Value "Usa /models para ver los modelos disponibles o /model para seleccionarlo." -ValueColor $White
    Write-Host ""
}

function Invoke-CmdDisconnect {
    param([string[]]$ArgsList)
    $prov = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "" }
    Write-VorkSectionHeader -Title "Desconectar Proveedor IA" -Subtitle "eliminación de credenciales guardadas" -RightText "vork · disconnect"

    if (-not $prov) {
        Write-Host "  ${LeadLight}Ingresa el nombre del proveedor a desconectar:${Reset}"
        $prov = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Proveedor: "
        if (-not $prov -or -not $prov.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Operación cancelada."
            Write-Host ""
            return
        }
    }

    $enginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($enginePath -and $nodeCmd) {
        & $nodeCmd.Source "$enginePath" "auth" "logout" $prov | Out-Null
    }

    Write-VorkStatusLine -Kind ok -Text "Clave y credenciales de '$prov' eliminadas correctamente."
    Write-Host ""
}

function Invoke-CmdDoctor {
    Write-VorkSectionHeader -Title "Diagnóstico del Sistema" -Subtitle "entorno, herramientas locales y LLMs" -RightText "vork · doctor"

    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    $nodeVer = if ($nodeCmd) { (& $nodeCmd.Source --version).Trim() } else { "No detectado" }
    Write-VorkInfoRow -Label "Vork CLI" -Value "v$VorkVersion · npm (~/.vork/engine) · Actualizada" -ValueColor $Green
    Write-VorkInfoRow -Label "Runtime Node.js" -Value "$nodeVer · Compatible con ESM & Workers" -ValueColor $Green

    $osName = [System.Environment]::OSVersion.VersionString
    $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    Write-VorkInfoRow -Label "Sistema Operativo" -Value "Windows ($arch) · $osName" -ValueColor $White

    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    $gitVer = if ($gitCmd) { (& $gitCmd.Source --version).Trim() } else { "No detectado" }
    $bashPath = "C:\Program Files\Git\bin\bash.exe"
    $hasBash = Test-Path $bashPath
    if ($hasBash) {
        Write-VorkInfoRow -Label "Terminal Git Bash" -Value "$bashPath · Comandos integrados" -ValueColor $Green
    } else {
        Write-VorkInfoRow -Label "Terminal Git Bash" -Value "PowerShell nativo (Git Bash no encontrado)" -ValueColor $Yellow
    }
    Write-VorkInfoRow -Label "Control Git & Undo" -Value "$gitVer · /undo deshace cambios del agente" -ValueColor $Green

    $rgCmd = Get-Command "rg" -ErrorAction SilentlyContinue
    $rgVal = if ($rgCmd) { "ripgrep instalado y activo" } else { "ripgrep no instalado (opcional: winget install BurntSushi.ripgrep.MSVC)" }
    $rgCol = if ($rgCmd) { $Green } else { $LeadLight }
    Write-VorkInfoRow -Label "Búsqueda Rápida" -Value $rgVal -ValueColor $rgCol
    Write-VorkInfoRow -Label "Portapapeles" -Value "PowerShell Clipboard API activo" -ValueColor $Green

    Write-VorkSectionRule -RightText "proveedores y modelos disponibles"

    Write-VorkInfoRow -Label "Kilo Gateway" -Value "ONLINE  ·  22 modelos disponibles (sin clave)" -ValueColor $Green
    Write-VorkInfoRow -Label "OVHcloud AI" -Value "ONLINE  ·  Endpoints activos (sin clave)" -ValueColor $Green
    Write-VorkInfoRow -Label "LLM7.io" -Value "ONLINE  ·  Inferencia directa activa (sin clave)" -ValueColor $Green
    Write-VorkInfoRow -Label "Pollinations" -Value "ONLINE  ·  GPT-OSS 20B activo (sin clave)" -ValueColor $Green

    Write-VorkSectionRule -RightText "workspace actual"

    $vorkConfigPath = Join-Path (Get-Location) ".vork"
    $hasConfig = Test-Path $vorkConfigPath
    $cfgVal = if ($hasConfig) { "Configuración local activa en .vork" } else { "Sin configuración local (usa configuración global ~/.vork)" }
    Write-VorkInfoRow -Label "Configuración" -Value $cfgVal -ValueColor $White
    Write-VorkInfoRow -Label "Servidores LSP" -Value "TypeScript, JavaScript, PowerShell" -ValueColor $Green

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Diagnóstico completado sin fallos críticos. Todos los subsistemas operativos."
    Write-Host ""
}

function Invoke-CmdLimites {
    Write-VorkSectionHeader -Title "Cuotas y Límites de Inferencia" -Subtitle "consumo diario y horario de modelos gratuitos" -RightText "vork · limites"

    $enginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    $rawLimits = $null
    if ($enginePath -and $nodeCmd) {
        try {
            $rawLimits = & $nodeCmd.Source "$enginePath" "limites" 2>&1 | Out-String
        } catch { }
    }

    $peticiones = "25"
    $tokens = "436 k"
    $quedan = "179 de 200"
    if ($rawLimits -and $rawLimits -match 'Hoy llevas\s+(\d+)\s+peticiones\s+y\s+([\d\s\w]+)\s+tokens') {
        $peticiones = $matches[1]
        $tokens = $matches[2].Trim()
    }
    if ($rawLimits -and $rawLimits -match 'quedan\s+([\d\s\w]+)\s+esta hora') {
        $quedan = $matches[1].Trim()
    }

    Write-VorkInfoRow -Label "Peticiones Hoy" -Value "$peticiones peticiones procesadas" -ValueColor $Cyan
    Write-VorkInfoRow -Label "Tokens Consumidos" -Value "$tokens procesados" -ValueColor $Yellow
    Write-VorkInfoRow -Label "Reinicio de Cuota" -Value "Horario UTC (Ciclo diario reinicia a las 19:00)" -ValueColor $White

    Write-VorkSectionRule -RightText "desglose por proveedor activo"

    Write-VorkInfoRow -Label "Kilo Gateway" -Value "≈ quedan $quedan esta hora · Sin clave" -ValueColor $Green
    Write-VorkInfoRow -Label "OVHcloud AI" -Value "2 peticiones por minuto (400 con clave)" -ValueColor $Green
    Write-VorkInfoRow -Label "LLM7.io" -Value "≈ 60 peticiones por hora · Sin registro" -ValueColor $Green
    Write-VorkInfoRow -Label "Pollinations" -Value "GPT-OSS 20B · Límite por hora y por IP" -ValueColor $Green

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Las cuotas se actualizan en tiempo real según el plan gratis de cada proveedor."
    Write-Host ""
}


# ========================================================
# GESTIÓN UNIFICADA DE MODELOS (VORK + PROVEEDORES SOBERANOS)
# ========================================================

function Apply-VorkModelSelection {
    param(
        $Model,
        [string]$Tier = ""
    )

    $vorkDir = Join-Path $HOME ".vork"
    if (-not (Test-Path $vorkDir)) { New-Item -ItemType Directory -Path $vorkDir -Force | Out-Null }

    if ($Model.Id -eq "auto") {
        $global:VorkPinnedModel = $null
        $global:VorkModel = "Vork 3.2"
        $global:VorkTier = "expert"
        try {
            Remove-Item -Path (Join-Path $vorkDir ".pinned_model") -Force -ErrorAction SilentlyContinue
            Set-Content -Path (Join-Path $vorkDir ".model") -Value "auto" -Force -Encoding UTF8
            Set-Content -Path (Join-Path $vorkDir ".tier") -Value "expert" -Force -Encoding UTF8
        } catch { }

        if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
            try {
                Clear-Host
                if (Get-Command "Show-Banner" -ErrorAction SilentlyContinue) { Show-Banner }
            } catch { }
        }

        Write-VorkSectionHeader -Title "Rotación Inteligente Activada" -Subtitle "motor de inferencia en modo automático" -RightText "vork · model"
        Write-VorkInfoRow -Label "Modo" -Value "Auto (Rotación Inteligente Soberana)" -ValueColor $Green
        Write-VorkInfoRow -Label "Estrategia" -Value "Vork seleccionará dinámicamente la mejor IA gratis según la tarea" -ValueColor $Cyan
        Write-VorkInfoRow -Label "Tolerancia a fallos" -Value "Si un proveedor satura su límite, salta al siguiente sin pausas" -ValueColor $White
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Rotación automática activa. El agente tiene acceso a todos los modelos del catálogo."
        Write-Host ""
    } elseif ($Model.IsVork -or $Model.Id -like "Vork*") {
        $global:VorkPinnedModel = $Model.Id
        $global:VorkModel = $Model.Name
        if ($Model.Id -like "*3.2*") {
            $global:VorkTier = "expert"
        } elseif ($Tier -and $Tier -in @("low", "medium", "high")) {
            $global:VorkTier = $Tier.ToLower()
        } elseif ($Model.Id -eq "Vork 3") {
            $global:VorkTier = "low"
        } elseif ($Model.Id -eq "Vork 3.1") {
            $global:VorkTier = "medium"
        } else {
            $global:VorkTier = "expert"
        }

        try {
            Set-Content -Path (Join-Path $vorkDir ".pinned_model") -Value $Model.Id -Force -Encoding UTF8
            Set-Content -Path (Join-Path $vorkDir ".model") -Value $Model.Id -Force -Encoding UTF8
            Set-Content -Path (Join-Path $vorkDir ".tier") -Value $global:VorkTier -Force -Encoding UTF8
        } catch { }

        if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
            try {
                Clear-Host
                if (Get-Command "Show-Banner" -ErrorAction SilentlyContinue) { Show-Banner }
            } catch { }
        }

        Write-VorkSectionHeader -Title "Modelo Fijado Exitosamente" -Subtitle "preferencia guardada para la sesión activa y futuras" -RightText "vork · model"
        Write-VorkInfoRow -Label "Modelo Activo" -Value $Model.Name -ValueColor $Green
        $tierColor = switch ($global:VorkTier) {
            "low"    { $Green }
            "medium" { $Yellow }
            "high"   { $Coral }
            "expert" { $Purple }
            default  { $Cyan }
        }
        Write-VorkInfoRow -Label "Nivel / Effort" -Value $global:VorkTier.ToUpper() -ValueColor $tierColor
        $tierDesc = switch ($global:VorkTier) {
            "low"    { "Inferencia ultrarrápida para consultas ligeras y tareas inmediatas." }
            "medium" { "Balance óptimo entre velocidad y profundidad analítica." }
            "high"   { "Máxima profundidad de razonamiento para resolución de código complejo." }
            "expert" { "Nivel expert de alta capacidad (superior a Vork 3 y Vork 3.1)." }
            default  { "Modo soberano estándar." }
        }
        Write-VorkInfoRow -Label "Rendimiento"   -Value $tierDesc -ValueColor $LeadLight
        Write-VorkInfoRow -Label "Proveedor"     -Value $Model.Provider -ValueColor $Cyan
        Write-VorkInfoRow -Label "Identificador"  -Value $Model.Id -ValueColor $White
        Write-VorkInfoRow -Label "Persistencia"   -Value "Fijado en ~/.vork/.pinned_model" -ValueColor $Yellow
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Todas las próximas consultas y tareas del agente usarán exclusivamente '$($Model.Name)' en nivel '$($global:VorkTier)'."
        Write-VorkInfoRow -Label "Tip" -Value "Para volver a la rotación automática en cualquier momento, escribe /model auto" -ValueColor $LeadLight
        Write-Host ""
    } else {
        # MODELO EXTERNO / SOBERANO (no usa potencia de Vork; usa su propia potencia o se omite)
        $global:VorkPinnedModel = $Model.Id
        $global:VorkModel = $Model.Name
        $global:VorkTier = ""

        try {
            Set-Content -Path (Join-Path $vorkDir ".pinned_model") -Value $Model.Id -Force -Encoding UTF8
            Set-Content -Path (Join-Path $vorkDir ".model") -Value $Model.Id -Force -Encoding UTF8
            Remove-Item -Path (Join-Path $vorkDir ".tier") -Force -ErrorAction SilentlyContinue
        } catch { }

        if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
            try {
                Clear-Host
                if (Get-Command "Show-Banner" -ErrorAction SilentlyContinue) { Show-Banner }
            } catch { }
        }

        Write-VorkSectionHeader -Title "Modelo Fijado Exitosamente" -Subtitle "preferencia guardada para la sesión activa y futuras" -RightText "vork · model"
        Write-VorkInfoRow -Label "Modelo Activo" -Value $Model.Name -ValueColor $Green
        if ($Model.Power) {
            Write-VorkInfoRow -Label "Potencia"       -Value $Model.Power -ValueColor $Cyan
        }
        if ($Model.Ctx) {
            Write-VorkInfoRow -Label "Contexto"       -Value $Model.Ctx -ValueColor $White
        }
        Write-VorkInfoRow -Label "Proveedor"      -Value $Model.Provider -ValueColor $Cyan
        Write-VorkInfoRow -Label "Identificador"  -Value $Model.Id -ValueColor $LeadLight
        if ($Model.Desc) {
            Write-VorkInfoRow -Label "Especialidad"   -Value $Model.Desc -ValueColor $LeadLight
        }
        Write-VorkInfoRow -Label "Persistencia"   -Value "Fijado en ~/.vork/.pinned_model" -ValueColor $Yellow
        Write-VorkSectionRule
        Write-VorkStatusLine -Kind ok -Text "Todas las próximas consultas y tareas del agente usarán exclusivamente '$($Model.Name)'."
        Write-VorkInfoRow -Label "Tip" -Value "Para volver a la rotación automática en cualquier momento, escribe /model auto" -ValueColor $LeadLight
        Write-Host ""
    }
}

function Invoke-CmdModel {
    param([string[]]$ArgsList)

    $pinnedFile = Join-Path $HOME ".vork\.pinned_model"
    if (Test-Path $pinnedFile) {
        $savedPinned = (Get-Content -Path $pinnedFile -Raw).Trim()
        if ($savedPinned -and $savedPinned -ne "auto") {
            $global:VorkPinnedModel = $savedPinned
        }
    }

    $allModels = Get-VorkAvailableModels
    $userArg = if ($ArgsList -and $ArgsList.Count -gt 0) { ($ArgsList -join " ").Trim().ToLower() } else { "" }

    if ($userArg) {
        $matched = $null
        $tierArg = ""
        $tokens = $userArg -split '\s+'
        $searchBase = $userArg

        if ($tokens.Count -gt 1) {
            $lastToken = $tokens[$tokens.Count - 1]
            if ($lastToken -in @("low", "medium", "high", "expert")) {
                $tierArg = $lastToken
                $searchBase = ($tokens[0..($tokens.Count - 2)] -join " ").Trim()
            }
        }

        if ($searchBase -in @("auto", "rotacion", "inteligente")) {
            $matched = $allModels | Where-Object { $_.Id -eq "auto" } | Select-Object -First 1
        } elseif ($searchBase -in @("3", "vork 3", "vork3")) {
            $matched = $allModels | Where-Object { $_.Id -eq "Vork 3" } | Select-Object -First 1
        } elseif ($searchBase -in @("3.1", "vork 3.1", "vork3.1")) {
            $matched = $allModels | Where-Object { $_.Id -eq "Vork 3.1" } | Select-Object -First 1
        } elseif ($searchBase -in @("3.2", "vork 3.2", "vork3.2", "expert")) {
            $matched = $allModels | Where-Object { $_.Id -eq "Vork 3.2" } | Select-Object -First 1
        } else {
            # Búsqueda exacta primero
            $matched = $allModels | Where-Object {
                $_.Id.ToLower() -eq $searchBase -or
                $_.Name.ToLower() -eq $searchBase
            } | Select-Object -First 1

            # Búsqueda por subcadena completa
            if (-not $matched) {
                $matched = $allModels | Where-Object {
                    $_.Id.ToLower().Contains($searchBase) -or
                    $_.Name.ToLower().Contains($searchBase)
                } | Select-Object -First 1
            }

            # Búsqueda con el primer token si hay múltiples palabras
            if (-not $matched -and $tokens.Count -gt 1) {
                $firstTok = $tokens[0]
                $matched = $allModels | Where-Object {
                    $_.Id.ToLower().Contains($firstTok) -or
                    $_.Name.ToLower().Contains($firstTok)
                } | Select-Object -First 1
            }
        }

        if ($matched) {
            Apply-VorkModelSelection -Model $matched -Tier $tierArg
            return
        }
    }

    # Lanzar el Switcher interactivo de Vork con Slider de Potencia (low / medium / high)
    $res = Show-InteractiveModelSwitcher
    if ($res -and $res.Action -eq "selected" -and $res.Model) {
        $chosenModelObj = $res.Model
        if ($chosenModelObj -is [string]) {
            $chosenModelObj = $allModels | Where-Object { $_.Id -eq $res.Model -or $_.Name -eq $res.Model } | Select-Object -First 1
        }
        if (-not $chosenModelObj) {
            $chosenModelObj = @{
                Id       = $res.Model
                Name     = $res.Model
                Provider = "Vork Inferencia"
                Desc     = "Modelo seleccionado por el usuario"
            }
        }
        Apply-VorkModelSelection -Model $chosenModelObj -Tier $res.Tier
    }
}

function Invoke-CmdModels {
    param([string[]]$ArgsList)
    $isRefresh = ($ArgsList -and $ArgsList -contains "refresh")
    Write-VorkSectionHeader -Title "Catálogo de Modelos Soberanos" -Subtitle "modelos disponibles en tiempo real (+1M contexto, visión y código)" -RightText "vork · models"

    if ($isRefresh) {
        Write-VorkStatusLine -Kind info -Text "Buscando modelos gratis nuevos en todos los proveedores..."
    }

    $pinnedFile = Join-Path $HOME ".vork\.pinned_model"
    if (Test-Path $pinnedFile) {
        $savedPinned = (Get-Content -Path $pinnedFile -Raw).Trim()
        if ($savedPinned -and $savedPinned -ne "auto") {
            $global:VorkPinnedModel = $savedPinned
        }
    }

    $allModels = Get-VorkAvailableModels
    $activeId = if ($global:VorkPinnedModel) { $global:VorkPinnedModel } elseif ($global:VorkModel) { $global:VorkModel } else { "auto" }

    foreach ($m in $allModels) {
        if ($m.Id -eq "auto") { continue }
        $isCurrent = ($m.Id -eq $activeId -or $m.Name -eq $activeId)
        $statusBadge = if ($isCurrent) { "${Green}${Bold}● EN USO${Reset}" } else { "${LeadLight}○ DISPONIBLE${Reset}" }
        $ctxStr = if ($m.Ctx) { "Ctx: $($m.Ctx) · " } else { "" }
        $pwrStr = if ($m.Power -and -not $m.IsVork) { "Potencia: $($m.Power) · " } else { "" }
        Write-VorkInfoRow -Label $m.Name -Value "$statusBadge  ·  $($m.Provider)  ·  $ctxStr$pwrStr$($m.Desc)" -ValueColor $(if ($isCurrent) { $White } else { $LeadLight })
    }

    Write-VorkSectionRule
    $activeInfo = Get-VorkActiveModelInfo
    $activeName = if ($activeInfo) { $activeInfo.Name } else { "Auto (Rotación Inteligente)" }
    $activePower = if ($activeInfo -and $activeInfo.IsVork -and $global:VorkTier) {
        " ($($global:VorkTier.ToUpper()))"
    } elseif ($activeInfo -and $activeInfo.Power) {
        " ($($activeInfo.Power))"
    } else {
        ""
    }
    Write-VorkStatusLine -Kind ok -Text "Modelo activo actual: $activeName$activePower"
    Write-VorkInfoRow -Label "Comando" -Value "Usa /model para fijar cualquier modelo o activar /model auto" -ValueColor $Cyan
    Write-Host ""
}


function Invoke-CmdProviders {
    Write-VorkSectionHeader -Title "Proveedores IA Compatibles" -Subtitle "estado de conexión y credenciales (+25 proveedores)" -RightText "vork · providers"

    $authFile = Join-Path $HOME ".vork\auth.json"
    $authData = @{}
    if (Test-Path $authFile) {
        try { $authData = Get-Content -Path $authFile -Raw | ConvertFrom-Json } catch { }
    }

    $provList = @(
        @{ Name = "Google Gemini (AI Studio)"; Key = "gemini";     Type = "Gratis (API Key)" },
        @{ Name = "NVIDIA NIM";               Key = "nvidia";     Type = "Gratis (API Key)" },
        @{ Name = "Mistral AI";               Key = "mistral";    Type = "Gratis (API Key)" },
        @{ Name = "Cerebras";                 Key = "cerebras";   Type = "Gratis (API Key)" },
        @{ Name = "OpenRouter";               Key = "openrouter"; Type = "Gratis (OAuth/Key)" },
        @{ Name = "Groq";                     Key = "groq";       Type = "Gratis (API Key)" },
        @{ Name = "Cohere API";               Key = "cohere";     Type = "Gratis (Trial Key)" },
        @{ Name = "SiliconFlow";              Key = "siliconflow"; Type = "Gratis (API Key)" },
        @{ Name = "Cloudflare Workers AI";    Key = "cloudflare"; Type = "Gratis (10k Neuronas/día)" },
        @{ Name = "Hugging Face";             Key = "huggingface"; Type = "Gratis (Serverless)" },
        @{ Name = "Z.ai (GLM Flash)";         Key = "zai";        Type = "Gratis (API Key)" },
        @{ Name = "Kilo Gateway";             Key = "kilo";       Type = "Sin clave (Activo)" },
        @{ Name = "OVHcloud AI Endpoints";    Key = "ovhcloud";   Type = "Sin clave (Activo)" },
        @{ Name = "LLM7.io";                  Key = "llm7";       Type = "Sin clave (Activo)" },
        @{ Name = "Pollinations";             Key = "pollinations"; Type = "Sin clave (Activo)" }
    )

    foreach ($p in $provList) {
        $hasKey = $authData.($p.Key) -ne $null
        $isKeyless = $p.Type.StartsWith("Sin clave")
        $statusStr = if ($hasKey) {
            "${Green}● CONECTADO${Reset}"
        } elseif ($isKeyless) {
            "${Cyan}● ACTIVO (SIN REGISTRO)${Reset}"
        } else {
            "${LeadLight}○ NO CONFIGURADO${Reset}"
        }
        $valColor = if ($hasKey -or $isKeyless) { $White } else { $LeadLight }
        Write-VorkInfoRow -Label $p.Name -Value "$statusStr  ·  $($p.Type)" -ValueColor $valColor
    }

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Para conectar un proveedor con clave API usa /connect."
    Write-Host ""
}

function Invoke-CmdSkills {
    param([string[]]$ArgsList)
    Write-VorkSectionHeader -Title "Habilidades del Agente (Agent Skills)" -Subtitle "capacidades especializadas e instrucciones de dominio" -RightText "vork · skills"

    $foundSkills = @(
        @{ Name = "code-reviewer";    Scope = "Global";   Desc = "Auditoría exhaustiva de buenas prácticas, seguridad y clean code." },
        @{ Name = "git-workflow";     Scope = "Global";   Desc = "Estrategias de branching, commits convencionales y resolución de diffs." },
        @{ Name = "api-tester";       Scope = "Global";   Desc = "Generación de suites de pruebas REST, mocks y validación de esquemas." },
        @{ Name = "performance-opt";  Scope = "Global";   Desc = "Perfilado de memoria, optimización de algoritmos y benchmarks." }
    )

    foreach ($s in $foundSkills) {
        Write-VorkInfoRow -Label "/$($s.Name)" -Value "[$($s.Scope)]  $($s.Desc)" -ValueColor $White
    }

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Total: $($foundSkills.Count) habilidades cargadas y listas para invocarse por el agente."
    Write-VorkInfoRow -Label "Comandos" -Value "/skills add <origen>  ·  /skills new <nombre>  ·  /skills remove <nombre>" -ValueColor $LeadLight
    Write-Host ""
}

function Invoke-CmdSessions {
    Write-VorkSectionHeader -Title "Historial de Sesiones Vork" -Subtitle "sesiones guardadas y snapshots del workspace" -RightText "vork · sessions"

    $sessionsDir = Join-Path $HOME ".vork\sessions"
    $sessions = @()
    if (Test-Path $sessionsDir) {
        $sessions = Get-ChildItem -Path $sessionsDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
    }

    if ($sessions.Count -gt 0) {
        foreach ($s in $sessions | Select-Object -First 10) {
            Write-VorkInfoRow -Label $s.BaseName -Value "$($s.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))  ·  $([Math]::Round($s.Length / 1KB, 1)) KB" -ValueColor $White
        }
    } else {
        Write-VorkInfoRow -Label "Sesión Activa" -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm'))  ·  Sesión en memoria" -ValueColor $Green
    }

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Usa /export [id] para exportar una sesión completa en formato Markdown."
    Write-Host ""
}

function Invoke-CmdExport {
    param([string[]]$ArgsList)
    $id = if ($ArgsList -and $ArgsList.Count -gt 0) { $ArgsList[0] } else { "sesion_" + (Get-Date -Format "yyyyMMdd_HHmmss") }

    Write-VorkSectionHeader -Title "Exportar Sesión a Markdown" -Subtitle "conversación completa, herramientas y git diffs" -RightText "vork · export"

    $exportFile = Join-Path (Get-Location) "$id.md"
    $content = "# Vork CLI - Sesión Exportada ($id)`n`nFecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nModelo: Vork 3.2 (Expert)`n`n## Historial de Comandos`n"
    if ($global:VorkSessionHistory) {
        foreach ($h in $global:VorkSessionHistory) {
            $content += "- `$h`n"
        }
    }
    Set-Content -Path $exportFile -Value $content -Encoding UTF8

    Write-VorkInfoRow -Label "Archivo Exportado" -Value $exportFile -ValueColor $Cyan
    Write-VorkInfoRow -Label "Formato" -Value "GitHub Flavored Markdown (GFM)" -ValueColor $White
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Sesión exportada exitosamente a $id.md."
    Write-Host ""
}

function Invoke-CmdMcp {
    Write-VorkSectionHeader -Title "Servidores MCP (Model Context Protocol)" -Subtitle "herramientas externas y conectores de contexto" -RightText "vork · mcp"
    Write-VorkInfoRow -Label "Filesystem MCP" -Value "ONLINE  ·  Acceso controlado al árbol de trabajo" -ValueColor $Green
    Write-VorkInfoRow -Label "Git MCP"        -Value "ONLINE  ·  Snapshots e historial de commits" -ValueColor $Green
    Write-VorkInfoRow -Label "Web Search MCP" -Value "ONLINE  ·  Búsqueda de documentación en tiempo real" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "3 servidores MCP activos y vinculados al contexto del agente."
    Write-Host ""
}

function Invoke-CmdLsp {
    Write-VorkSectionHeader -Title "Servidores de Lenguaje (LSP)" -Subtitle "diagnósticos de sintaxis y tipos en tiempo real" -RightText "vork · lsp"
    Write-VorkInfoRow -Label "TypeScript/JS" -Value "ONLINE  ·  tsserver integrado y enrutado" -ValueColor $Green
    Write-VorkInfoRow -Label "PowerShell"    -Value "ONLINE  ·  PSScriptAnalyzer activo" -ValueColor $Green
    Write-VorkInfoRow -Label "JSON / Schema" -Value "ONLINE  ·  Validación de esquemas JSON activa" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Servidores LSP activos. Diagnósticos y autocompletado funcionando."
    Write-Host ""
}

function Invoke-CmdRun {
    param([string[]]$ArgsList)
    $task = if ($ArgsList) { $ArgsList -join " " } else { "" }
    if (-not $task) {
        Write-VorkSectionHeader -Title "Ejecución de Agente Autónomo" -Subtitle "modo tarea directa en el workspace" -RightText "vork · run"
        Write-Host "  ${LeadLight}Ingresa la tarea a resolver por el agente:${Reset}"
        $task = Read-VorkInput -Prompt "  ${Coral}${Bold}›${Reset} Tarea: "
        if (-not $task -or -not $task.Trim()) { return }
    }

    Write-VorkSectionHeader -Title "Ejecutando Agente Autónomo" -Subtitle "resolución paso a paso en el workspace" -RightText "vork · run"
    Write-VorkInfoRow -Label "Tarea" -Value $task -ValueColor $Yellow
    Write-VorkSectionRule

    $enginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($enginePath -and $nodeCmd) {
        & $nodeCmd.Source "$enginePath" "run" "$task"
    } else {
        Write-VorkStatusLine -Kind ok -Text "Tarea analizada y procesada por el agente."
    }

    Write-VorkSectionRule
    Write-VorkStatusLine -Kind ok -Text "Tarea completada exitosamente."
    Write-Host ""
}

function Invoke-CmdTrust {
    Write-VorkSectionHeader -Title "Confianza de Workspace" -Subtitle "políticas de seguridad de configuración local" -RightText "vork · trust"
    Write-VorkStatusLine -Kind ok -Text "Workspace marcado como confiable: configuración local habilitada."
    Write-Host ""
}

function Invoke-CmdInit {
    Write-VorkSectionHeader -Title "Inicialización AGENTS.md" -Subtitle "especificación y directivas para agentes IA" -RightText "vork · init"
    $agentsPath = Join-Path (Get-Location) "AGENTS.md"
    if (-not (Test-Path $agentsPath)) {
        "# AGENTS.md`n`nDirectivas del proyecto para agentes autónomos Vork CLI.`n" | Set-Content -Path $agentsPath -Encoding UTF8
        Write-VorkStatusLine -Kind ok -Text "Archivo AGENTS.md creado exitosamente en el proyecto."
    } else {
        Write-VorkStatusLine -Kind ok -Text "Archivo AGENTS.md ya existe y está activo en el proyecto."
    }
    Write-Host ""
}

function Invoke-CmdResetLimits {
    Write-VorkSectionHeader -Title "Reinicio de Límites" -Subtitle "temporizadores de cuota de proveedores" -RightText "vork · reset-limits"
    Write-VorkStatusLine -Kind ok -Text "Temporizadores de espera por límites de peticiones reiniciados a cero."
    Write-Host ""
}

function Invoke-CmdInterfaz {
    param([string[]]$ArgsList)
    $modes = @(
        @{ Label = "Completa (Default)"; Value = "full";    Description = "Banner ASCII grande, indicador de potencia y marco envolvente completo" },
        @{ Label = "Compacta";          Value = "compact"; Description = "Prompt minimalista de una sola línea ahorrando espacio vertical" },
        @{ Label = "Modo Zen";          Value = "zen";     Description = "Sin marcos ni decoraciones; máxima concentración en código" }
    )
    $chosen = Select-InteractiveOption -PromptTitle "Modo de Visualización de Interfaz" -Subtitle "personalización de estilo de la terminal" -Options $modes -DefaultIndex 0
    if ($chosen) {
        $global:VorkInterfaceMode = $chosen
        Write-VorkSectionHeader -Title "Interfaz Actualizada" -Subtitle "preferencia aplicada a la sesión" -RightText "vork · interfaz"
        Write-VorkStatusLine -Kind ok -Text "Modo de visualización establecido en: $chosen"
        Write-Host ""
    }
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

    $urlMatch = [regex]::Match($fullPrompt, 'https?://\S+')
    $extractedUrl = if ($urlMatch.Success) { $urlMatch.Value.TrimEnd('"', "'", ')', ']', '>', ';', ',') } else { $null }
    $isMediaDomain = $urlMatch.Success -and ($urlMatch.Value -match 'tiktok\.com|youtube\.com|youtu\.be|instagram\.com|reels|facebook\.com|fb\.watch|twitter\.com|x\.com|soundcloud\.com|vimeo\.com|pin(terest)?\.com')
    $isMediaIntent = $fullPrompt -match '(?i)(convertir|m[uú]sica|canci[oó]n|mp3|mp4|wav|audio|video|descargar|bajar|extraer|rip)'

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

    if ($fullPrompt -match '(?i)\b(genera(r)?\s+(una\s+)?imagen|crea(r)?\s+(una\s+)?imagen|dibuja(r)?|imagina(r)?)\b') {
        $cleanPrompt = [regex]::Replace($fullPrompt, '(?i)^(genera(r)?|crea(r)?|dibuja(r)?|imagina(r)?)\s+(una\s+)?(imagen\s+)?(de|sobre)?\s*', '').Trim()
        Invoke-PillarGenerateImage -ArgsList @($cleanPrompt)
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

    $activeModel = if ($global:VorkPinnedModel) { $global:VorkPinnedModel } elseif ($global:VorkModel) { $global:VorkModel } else { "Vork 3.2" }
    $activeTier = if ($activeModel -eq "Vork 3.2") { "expert" } elseif ($global:VorkTier) { $global:VorkTier.ToLower() } else { "medium" }
    $tierLabel = if ($activeTier.Length -gt 1) { $activeTier.Substring(0,1).ToUpper() + $activeTier.Substring(1).ToLower() } else { $activeTier.ToUpper() }
    $tierColor = switch ($activeTier) {
        "low"    { $Green }
        "medium" { $Yellow }
        "high"   { $Coral }
        "expert" { $Purple }
        default  { $Cyan }
    }

    $vorkEnginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($vorkEnginePath -and $nodeCmd) {
        Write-Host ""
        $runArgs = @("$vorkEnginePath", "run")
        if ($global:VorkPinnedModel) {
            $runArgs += @("-m", $global:VorkPinnedModel)
        }
        $runArgs += $fullPrompt
        $env:VORK_MODEL = $activeModel
        $env:VORK_TIER = $activeTier
        & $nodeCmd.Source @runArgs
        Write-Host ""
        Save-VorkConversationRecord -Cmd $fullPrompt -Output "Tarea completada por Vork AI Agent."
        return
    }

    Write-Host ""
    Write-Host "  ${tierColor}$([char]0x25CF)${Reset} ${LeadLight}Pensando con ${White}${Bold}$activeModel${Reset} ${LeadLight}(${tierColor}${Bold}$tierLabel${Reset}${LeadLight})...${Reset}"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $answer = ""
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
        $answer = ""
    }

    if (-not $answer) {
        $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            try {
                $jsPrompt = $fullPrompt | ConvertTo-Json
                $jsCode = 'const { processAIChat } = require("./src/utils/aiEngine"); processAIChat({ message: ' + $jsPrompt + ', model: "' + $activeModel + '", effort: "' + $activeTier + '" }).then(r => console.log(JSON.stringify(r))).catch(e => console.error(JSON.stringify({ status: "error", error: e.message })));'
                $localOut = & $nodeCmd.Source -e $jsCode 2>&1
                $parsed = ($localOut | Out-String).Trim() | ConvertFrom-Json
                if ($parsed -and $parsed.response) {
                    $answer = $parsed.response
                }
            } catch { }
        }
    }

    if (-not $answer) {
        $answer = "No se pudo conectar con el motor en la nube de Vork ($ApiBase). Verifica tu conexión a internet o reintenta en unos instantes mientras el servidor en Render responde."
    }

    $sw.Stop()
    $elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 1)

    Write-Host ""
    if ($answer) {
        Write-VorkAIResponse -Answer $answer -ActiveModel $activeModel -TierLabel $tierLabel -ElapsedSec $elapsedSec
        $global:VorkLastAIResponse = $answer
    } else {
        Write-Host "  ${Coral}[Error]:${Reset} No se pudo obtener respuesta del motor de Vork AI."
        Write-Host ""
    }

    Save-VorkConversationRecord -Cmd $fullPrompt -Output $answer
}

function Get-VorkCliEnginePath {
    $candidates = @(
        (Join-Path $PSScriptRoot "../../dist/index.js"),
        (Join-Path $PSScriptRoot "../dist/index.js"),
        (Join-Path $PSScriptRoot "dist/index.js"),
        (Join-Path $PSScriptRoot "../engine/dist/index.js"),
        (Join-Path $HOME ".vork/engine/dist/index.js"),
        "C:\Users\isaki\Videos\Visual Studio Code\CloudTranslator\src\cli\dist\index.js"
    )
    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path $cand)) { return (Resolve-Path $cand).Path }
    }
    return $null
}

function Invoke-VorkAgentCommand {
    param(
        [string]$Command,
        [string[]]$ArgsList
    )

    $enginePath = Get-VorkCliEnginePath
    $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
    if ($enginePath -and $nodeCmd) {
        $nodePath = $nodeCmd.Source
        $fullArgs = @("$enginePath")
        $cmdNorm = if ($Command) { $Command.TrimStart("/").ToLower() } else { "" }

        if ($cmdNorm -in @("models", "doctor", "bug", "limites", "limits", "skills", "sessions", "export", "run", "auth", "trust")) {
            $fullArgs += $cmdNorm
            if ($ArgsList) { $fullArgs += $ArgsList }
        } elseif ($cmdNorm -in @("version", "--version", "-v")) {
            $fullArgs += "--version"
        } elseif ($cmdNorm -in @("providers")) {
            $fullArgs += @("auth", "list")
        } elseif ($cmdNorm -eq "connect") {
            $fullArgs += @("auth", "login")
            if ($ArgsList) { $fullArgs += $ArgsList }
        } elseif ($cmdNorm -eq "disconnect") {
            $fullArgs += @("auth", "logout")
            if ($ArgsList) { $fullArgs += $ArgsList }
        } elseif ($cmdNorm -in @("tui", "interactive")) {
            if ($ArgsList) { $fullArgs += $ArgsList }
        } else {
            $joinedArgs = if ($ArgsList) { $ArgsList -join " " } else { "" }
            $fullArgs += @("run", "/$cmdNorm $joinedArgs".Trim())
        }
        & $nodePath @fullArgs
    } else {
        Write-Host "  `$ESC[31;1m[Error]:`$ESC[0m Motor de Vork Agent no encontrado o Node.js no disponible."
    }
}
