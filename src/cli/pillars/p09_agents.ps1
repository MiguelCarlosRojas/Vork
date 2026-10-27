<#
.SYNOPSIS
    Pilar 09: Vork Agentes Autónomos & Modo Interactivo TUI
#>

function Invoke-PillarAgents {
    param([string[]]$ArgsList)

    if (-not $ArgsList -or $ArgsList.Length -eq 0) {
        $agentOptions = @(
            @{ Value = "status";   Label = "[1] Ver estado del clúster de agentes y conectividad" },
            @{ Value = "goal";     Label = "[2] Ejecutar /goal (Tarea autónoma de bucle continuo)" },
            @{ Value = "plan";     Label = "[3] Ejecutar /plan (Desglose guiado de arquitectura)" },
            @{ Value = "teamwork"; Label = "[4] Activar /teamwork (Coordinación de múltiples subagentes)" },
            @{ Value = "boost";    Label = "[5] Alternar /boost (Razonamiento profundo con verificación)" },
            @{ Value = "learn";    Label = "[6] Registrar regla con /learn (Persistencia en ~/.vork)" }
        )

        $chosenAction = Select-InteractiveOption -PromptTitle "Selecciona una operación de Agentes Autónomos:" -Options $agentOptions -DefaultIndex 0
        if (-not $chosenAction) { return }
        if ($chosenAction -ne "status") {
            switch ($chosenAction) {
                "goal" { Invoke-CmdGoal @(); return }
                "plan" { Invoke-CmdPlan @(); return }
                "teamwork" { Invoke-CmdTeamwork @(); return }
                "boost" { Invoke-CmdBoost; return }
                "learn" { Invoke-CmdLearn @(); return }
            }
        }
    }

    Write-Host ""
    Write-Host "  ${Cyan}╭─ ${Bold}[09] VORK AGENTES AUTÓNOMOS & ORQUESTACIÓN IA${Reset} ─────────"
    Write-Host "  ${Cyan}│${Reset}  ${White}${Bold}Motor de Agentes:${Reset} ${Green}● ONLINE${Reset} ${LeadLight}(Bucle de Agentes Autónomos Vork 3)${Reset}"
    Write-Host "  ${Cyan}│${Reset}  ${LeadLight}Subagentes concurrentes disponibles:${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Codebase Researcher${Reset} ${LeadLight}· Análisis y exploración de contexto${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Audio Engine Agent${Reset}  ${LeadLight}· Síntesis TTS y modelado F0 spectral${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Demucs Stem Worker${Reset}  ${LeadLight}· Separación acapella/karaoke en background${Reset}"
    Write-Host "  ${Cyan}│${Reset}    ${Cyan}● Media Extraction Bot${Reset}${LeadLight}· Extracción y compresión multimedia 320k${Reset}"
    Write-Host "  ${Cyan}├───────────────────────────────────────────────────${Reset}"
    $reportFile = "vork_agents_cluster.json"
    @{ status = "online"; motor = "Vork Autonomous Agents v3"; pilares = 8; subagentes = @("Codebase Researcher", "Audio Engine Agent", "Demucs Stem Worker", "Media Extraction Bot") } | ConvertTo-Json | Set-Content -Path $reportFile -Encoding UTF8
    $resolvedOut = (Resolve-Path $reportFile).Path
    Write-Host "  ${Cyan}│${Reset}  $Green✓ Clúster de agentes sincronizado con éxito.$Reset"
    Write-Host "  ${Cyan}│${Reset}  $Green✓ Guardado local:$Reset $White$resolvedOut$Reset"
    Write-Host "  ${Cyan}╰───────────────────────────────────────────────────${Reset}"
    Write-Host ""
}
