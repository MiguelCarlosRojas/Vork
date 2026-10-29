<#
.SYNOPSIS
    Vork CLI - Modulo Core: Auto-Update Silencioso y Sincronizacion Atómica
#>

function Check-And-AutoUpdate {
    param([switch]$Force)
    
    $cacheDir = Join-Path $HOME ".vork"
    $checkFile = Join-Path $cacheDir ".last_check"
    $settingsFile = Join-Path $cacheDir "settings.json"
    $shouldCheck = $Force

    $autoUpdatePref = "silent"
    if (Test-Path $settingsFile) {
        try {
            $sData = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($sData.auto_update) { $autoUpdatePref = [string]$sData.auto_update }
        } catch { }
    }

    # Si está desactivado y no es invocación manual, salir
    if (-not $Force -and $autoUpdatePref -eq "off") {
        return
    }
    
    if (-not $shouldCheck) {
        if (-not (Test-Path $checkFile)) {
            $shouldCheck = $true
        } else {
            try {
                $lastCheck = (Get-Item $checkFile).LastWriteTime
                if ((Get-Date) - $lastCheck -gt (New-TimeSpan -Hours 1)) {
                    $shouldCheck = $true
                }
            } catch {
                $shouldCheck = $true
            }
        }
    }
    
    if ($shouldCheck) {
        try {
            if ($Force) {
                Write-VorkSectionHeader -Title "Actualización de Vork CLI" -Subtitle "verificando versiones en la nube..." -RightText "vork · update"
                Write-VorkInfoRow -Label "Versión local" -Value "v$VorkVersion" -ValueColor $Cyan
                Write-VorkInfoRow -Label "Servidor" -Value $ApiBase -ValueColor $LeadLight
                Write-VorkSectionRule
            }

            $remoteInfo = Invoke-RestMethod -Uri "$ApiBase/api/cli/info" -TimeoutSec 4 -ErrorAction Stop
            Set-Content -Path $checkFile -Value (Get-Date).ToString("o") -ErrorAction SilentlyContinue

            $remoteVer = if ($remoteInfo -and $remoteInfo.version) { [string]$remoteInfo.version } else { $VorkVersion }
            $isNewer = try { [version]$remoteVer -gt [version]$VorkVersion } catch { $remoteVer -ne $VorkVersion }

            if ($Force) {
                if (-not $isNewer) {
                    Write-VorkStatusLine -Kind ok -Text "Vork CLI ya está en su versión más reciente (v$VorkVersion)."
                    Write-Host ""
                    return
                }

                # Preguntar confirmación al usuario para actualizar
                $upOptions = @(
                    @{ Value = "yes"; Label = "Actualizar ahora (Recomendado)"; Description = "Descarga e instala Vork CLI v$remoteVer" },
                    @{ Value = "no";  Label = "Omitir por ahora";               Description = "Permanecer en la versión actual v$VorkVersion" }
                )
                $chosen = Select-InteractiveOption -PromptTitle "¿Deseas actualizar Vork CLI a la versión v$remoteVer?" -Subtitle "nueva versión disponible" -Options $upOptions -DefaultIndex 0
                if ($chosen -ne "yes") {
                    Write-VorkStatusLine -Kind warn -Text "Actualización omitida por el usuario."
                    Write-Host ""
                    return
                }
            } else {
                # Segundo plano
                if (-not $isNewer) { return }
                if ($autoUpdatePref -eq "prompt") {
                    return
                }
            }

            # Proceder con la actualización atómica
            if ($Force) {
                Write-VorkStatusLine -Kind step -Text "Sincronizando binarios con Vork Cloud v$remoteVer"
            }
            $targetScript = if ($PSCommandPath) { $PSCommandPath } else { Join-Path $cacheDir "bin\vork.ps1" }
            
            Invoke-RestMethod -Uri "$ApiBase/cli/vork.ps1" -OutFile "$targetScript.tmp" -TimeoutSec 15 -ErrorAction Stop
            if (Test-Path "$targetScript.tmp") {
                Move-Item -Path "$targetScript.tmp" -Destination $targetScript -Force
                if ($Force) {
                    Write-VorkStatusLine -Kind ok -Text "Vork CLI actualizado exitosamente a v$remoteVer."
                    Write-Host ""
                }
                Send-VorkNotification -Title "Vork CLI Actualizado" -Message "Vork CLI sincronizado exitosamente con la versión v$remoteVer."
            }
        } catch {
            if ($Force) {
                Write-VorkStatusLine -Kind error -Text "Error al consultar o instalar actualización" -Detail $_.Exception.Message
                Write-Host ""
            }
        }
    }
}
