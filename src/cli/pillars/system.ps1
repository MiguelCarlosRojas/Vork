<#
.SYNOPSIS
    Modulos de Sistema: Version y Telemetria en Vivo (Health)
#>

function Invoke-PillarVersion {
    $archLabel = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE } else { "unknown" }
    Write-Host ""
    Write-Host "  $ESC[44;97;1m VORK CLI $Reset $White$Bold v$VorkVersion$Reset"
    Write-Host "  $White Backend:$Reset  $Cyan$ApiBase$Reset"
    Write-Host "  $White Pilares:$Reset  $Green 9 Pilares Operacionales Activos$Reset"
    Write-Host "  $White Motor:$Reset    $White PowerShell $($PSVersionTable.PSVersion) [$archLabel]$Reset"
    Write-Host ""
}

function Invoke-PillarHealth {
    Invoke-CmdStatus
}
