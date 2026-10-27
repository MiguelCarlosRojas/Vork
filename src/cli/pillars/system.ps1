<#
.SYNOPSIS
    Modulos de Sistema: Version y Telemetria en Vivo (Health)
#>

function Invoke-PillarVersion {
    $archLabel = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE } else { "unknown" }
    Write-Host ""
    Write-Host "  $ESC[44;97;1m VORK CLI $Reset $White$Bold v$VorkVersion$Reset"
    Write-Host "  $Gray Backend:$Reset  $Cyan$ApiBase$Reset"
    Write-Host "  $Gray Pilares:$Reset  $Green 9 Pilares Operacionales Activos$Reset"
    Write-Host "  $Gray Motor:$Reset    $White PowerShell $($PSVersionTable.PSVersion) [$archLabel]$Reset"
    Write-Host ""
}

function Invoke-PillarHealth {
    Write-Host ""
    Write-Host "  $Cyan╭─ [TELEMETRÍA Y ESTADO DE LOS 9 PILARES] ──────────$Reset"
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/health" -Method Get
        Write-Host "  $Cyan│$Reset  $Gray Servidor:$Reset  $Green● ONLINE$Reset ${Dim}($ApiBase)${Reset}"
        Write-Host "  $Cyan│$Reset  $Gray Pilares:$Reset   $White$($res.pillars) / 9 Operacionales$Reset"
        Write-Host "  $Cyan│$Reset  $Gray Uptime:$Reset    $White$($res.uptime)s$Reset"
        Write-Host "  $Cyan├───────────────────────────────────────────────────$Reset"
        if ($res.services) {
            $res.services.PSObject.Properties | ForEach-Object {
                Write-Host "  $Cyan│$Reset  $Green●$Reset $($_.Value.name): $Dim$($_.Value.status)$Reset"
            }
        }
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    } catch {
        Write-Host "  $Cyan│$Reset  ${Coral}[Offline]:${Reset} Servidor no responde en $ApiBase"
        Write-Host "  $Cyan╰───────────────────────────────────────────────────$Reset"
    }
    Write-Host ""
}
