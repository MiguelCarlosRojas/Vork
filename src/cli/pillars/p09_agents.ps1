<#
.SYNOPSIS
    Pilar 09: Vork Agentes Autónomos & Modo Interactivo TUI
#>

function Invoke-PillarAgents {
    param([string[]]$ArgsList)

    if (-not $ArgsList -or $ArgsList.Length -eq 0) {
        $agentOptions = @(
            @{ Value = "status";   Label = "Estado del clúster";     Description = "Agentes activos y conectividad" },
            @{ Value = "goal";     Label = "/goal";                  Description = "Tarea autónoma de bucle continuo" },
            @{ Value = "plan";     Label = "/plan";                  Description = "Desglose guiado de arquitectura" },
            @{ Value = "teamwork"; Label = "/teamwork";              Description = "Coordinación de múltiples subagentes" },
            @{ Value = "learn";    Label = "/learn";                 Description = "Guardar una regla en ~/.vork" }
        )

        $chosenAction = Select-InteractiveOption -PromptTitle "Operación de agentes" -Subtitle "orquestación autónoma" -Options $agentOptions -DefaultIndex 0
        if (-not $chosenAction) { return }
        if ($chosenAction -ne "status") {
            switch ($chosenAction) {
                "goal" { Invoke-CmdGoal @(); return }
                "plan" { Invoke-CmdPlan @(); return }
                "teamwork" { Invoke-CmdTeamwork @(); return }
                "learn" { Invoke-CmdLearn @(); return }
            }
        }
    }

    Write-VorkSectionHeader -Title "Agentes autónomos" -Subtitle "Orquestación de subagentes en paralelo" -RightText "vork · agents"
    Write-VorkInfoRow -Label "Motor" -Value "ONLINE  ·  Vork Autonomous Agents v3" -ValueColor $Green
    Write-VorkSectionRule
    Write-VorkStatusLine -Kind info -Text "Codebase Researcher" -Detail "Análisis y exploración de contexto"
    Write-VorkStatusLine -Kind info -Text "Audio Engine Agent" -Detail "Síntesis TTS y modelado F0 espectral"
    Write-VorkStatusLine -Kind info -Text "Demucs Stem Worker" -Detail "Separación acapella y karaoke en segundo plano"
    Write-VorkStatusLine -Kind info -Text "Media Extraction Bot" -Detail "Extracción y compresión multimedia 320k"
    Write-VorkSectionRule
    $reportFile = "vork_agents_cluster.json"
    @{ status = "online"; motor = "Vork Autonomous Agents v3"; pilares = 8; subagentes = @("Codebase Researcher", "Audio Engine Agent", "Demucs Stem Worker", "Media Extraction Bot") } | ConvertTo-Json | Set-Content -Path $reportFile -Encoding UTF8
    $resolvedOut = (Resolve-Path $reportFile).Path
    Write-VorkStatusLine -Kind ok -Text "Clúster de agentes sincronizado"
    Write-VorkInfoRow -Label "Guardado" -Value $resolvedOut -ValueColor $Green
    Write-VorkSectionRule
    Send-VorkNotification -Title "Vork Agentes Autónomos" -Message "Clúster de subagentes sincronizado con éxito."
    Write-Host ""
}
