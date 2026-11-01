# ==============================================================================
# Vork CLI - Windows PowerShell Installer v1.0.3
# Despliega el motor completo de Vork CLI consumiendo src/cli/src
# Soporte para Motor de Agente IA Soberano y los 9 Pilares Operacionales
# ==============================================================================

$ErrorActionPreference = "Stop"

$Coral = [char]27 + "[38;2;255;107;74m"
$Cyan = [char]27 + "[38;2;56;189;248m"
$Green = [char]27 + "[38;2;74;222;128m"
$Yellow = [char]27 + "[38;2;234;179;8m"
$Purple = [char]27 + "[38;2;168;85;247m"
$WhiteBold = [char]27 + "[97;1m"
$White = [char]27 + "[97m"
$Dim = [char]27 + "[2m"
$Reset = [char]27 + "[0m"

$devIdentity = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.Trim() } else { [System.Environment]::MachineName.Trim() }
$currentPath = (Get-Location).Path
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$shortPath = $currentPath.Replace($userHome, "~")
if ($shortPath.Length -gt 40) {
    $shortPath = ".../" + (Split-Path $currentPath -Leaf)
}

Clear-Host
Write-Host ""
Write-Host "  ${WhiteBold}VORK CLI v1.0.3${Reset}                            ${Coral}██     ██${Reset}"
Write-Host "  ${WhiteBold}Vork 3.2${Reset} ${Purple}(Expert)${Reset}                          ${Coral}▀██   ██▀${Reset}"
Write-Host "  ${White}$devIdentity${Reset} ${Cyan}(Vork AI)${Reset}                      ${Coral}▀██ ██▀${Reset}"
Write-Host "  ${Coral}❯${Reset} ${White}$shortPath${Reset}     ${Coral}▀███▀${Reset}"
Write-Host ""

Write-Host "  ${Cyan}==>${Reset} Verificando entorno del sistema..."
$arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "      Arquitectura: $arch"
Write-Host "      PowerShell:   $($PSVersionTable.PSVersion)"

# Directorios globales de instalación
$installDir = Join-Path $userHome ".vork"
$binDir = Join-Path $installDir "bin"
$engineDir = Join-Path $installDir "engine"

if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
if (-not (Test-Path $engineDir)) { New-Item -ItemType Directory -Path $engineDir -Force | Out-Null }

# 1. Localizar el directorio fuente src/cli/src
$sourceCandidates = @(
    (Join-Path $PSScriptRoot "src"),
    (Join-Path $PSScriptRoot "src/cli/src"),
    (Join-Path $currentPath "src/cli/src"),
    (Join-Path $currentPath "src")
)

$srcDir = $null
foreach ($cand in $sourceCandidates) {
    if (Test-Path (Join-Path $cand "core/config.ps1")) {
        $srcDir = (Resolve-Path $cand).Path
        break
    }
}

$cliRoot = if ($srcDir) { (Resolve-Path (Join-Path $srcDir "..")).Path } else { $null }

if ($srcDir -and (Test-Path $srcDir)) {
    Write-Host "  ${Cyan}==>${Reset} Consumiendo código fuente local desde: ${WhiteBold}$srcDir${Reset}"

    # Lista ordenada de módulos PowerShell para ensamblar
    $modules = @(
        "core/config.ps1",
        "ui/toolkit.ps1",
        "ui/banner.ps1",
        "ui/cards.ps1",
        "ui/help.ps1",
        "pillars/p01_translate.ps1",
        "pillars/p02_tts.ps1",
        "pillars/p03_clone.ps1",
        "pillars/p04_media.ps1",
        "pillars/p05_separate.ps1",
        "pillars/p06_image.ps1",
        "pillars/p07_remove_bg.ps1",
        "pillars/p08_generate_image.ps1",
        "pillars/p09_agents.ps1",
        "pillars/commands.ps1",
        "pillars/system.ps1",
        "core/updater.ps1",
        "core/router.ps1"
    )

    $fullPs1 = ""
    foreach ($mod in $modules) {
        $modPath = Join-Path $srcDir $mod
        if (Test-Path $modPath) {
            $content = Get-Content -Path $modPath -Raw -Encoding UTF8
            $fullPs1 += "`r`n# ========================================================`r`n# MODULE: $mod`r`n# ========================================================`r`n" + $content + "`r`n"
        } else {
            Write-Warning "Módulo no encontrado: $modPath"
        }
    }

    # Guardar vork.ps1 ensamblado directamente en ~/.vork/bin
    $outPs1 = Join-Path $binDir "vork.ps1"
    [System.IO.File]::WriteAllText($outPs1, $fullPs1, [System.Text.Encoding]::UTF8)
    $sizeKb = [math]::Round($fullPs1.Length / 1024, 1)
    Write-Host ("  {0}[OK]{1} Lanzador ensamblado en {2} ({3} KB)" -f $Green, $Reset, $outPs1, $sizeKb)

    # Desplegar motor de TypeScript a ~/.vork/engine
    $localDist = Join-Path $cliRoot "dist"
    $engineDist = Join-Path $engineDir "dist"

    if (Test-Path (Join-Path $localDist "index.js")) {
        Write-Host "  ${Cyan}==>${Reset} Sincronizando distribución compilada del motor TypeScript..."
        if (-not (Test-Path $engineDist)) { New-Item -ItemType Directory -Path $engineDist -Force | Out-Null }
        Copy-Item -Path "$localDist\*" -Destination $engineDist -Recurse -Force
    } elseif (Get-Command "npm" -ErrorAction SilentlyContinue) {
        Write-Host "  ${Cyan}==>${Reset} Compilando motor TypeScript de Vork CLI..."
        Push-Location $cliRoot
        npm run build | Out-Null
        Pop-Location
        if (-not (Test-Path $engineDist)) { New-Item -ItemType Directory -Path $engineDist -Force | Out-Null }
        Copy-Item -Path "$localDist\*" -Destination $engineDist -Recurse -Force
    }

    # Copiar package.json y dependencias si existen
    $pkgJson = Join-Path $cliRoot "package.json"
    if (Test-Path $pkgJson) {
        Copy-Item -Path $pkgJson -Destination (Join-Path $engineDir "package.json") -Force
    }
    $localNodeModules = Join-Path $cliRoot "node_modules"
    if (Test-Path $localNodeModules) {
        $targetModules = Join-Path $engineDir "node_modules"
        if (-not (Test-Path $targetModules)) {
            Write-Host "  ${Cyan}==>${Reset} Enlazando módulos de dependencias del motor..."
            try {
                New-Item -ItemType Junction -Path $targetModules -Target $localNodeModules -Force | Out-Null
            } catch {
                Copy-Item -Path $localNodeModules -Destination $targetModules -Recurse -Force
            }
        }
    }
} else {
    Write-Host "  ${Cyan}==>${Reset} Descargando componentes desde el repositorio oficial..."
    $ApiBase = if ($env:VORK_API) { $env:VORK_API } else { "https://vork-st1k.onrender.com" }
    $cliPs1Path = Join-Path $binDir "vork.ps1"
    try {
        Invoke-RestMethod -Uri "$ApiBase/cli/vork.ps1" -OutFile $cliPs1Path -TimeoutSec 15 -ErrorAction Stop
        Write-Host ('  ' + $Green + '[OK]' + $Reset + ' vork.ps1 descargado.')
    } catch {
        Write-Host "  $Yellow [WARN] $Reset No se pudo descargar vork.ps1 desde el servidor backend."
    }
}

# 2. Generar wrappers ejecutables para Windows CMD y Terminal
$cliPs1Path = Join-Path $binDir "vork.ps1"
$cmdLines = @(
    '@echo off',
    ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" %*' -f $cliPs1Path)
)
$cmdWrapper = ($cmdLines -join [Environment]::NewLine) + [Environment]::NewLine

Set-Content -Path (Join-Path $binDir "vork.cmd") -Value $cmdWrapper -Encoding ASCII
Set-Content -Path (Join-Path $binDir "vk.cmd") -Value $cmdWrapper -Encoding ASCII
Set-Content -Path (Join-Path $binDir "vork-cli.cmd") -Value $cmdWrapper -Encoding ASCII
Set-Content -Path (Join-Path $binDir "ct.cmd") -Value $cmdWrapper -Encoding ASCII

# 3. Configurar binDir en el PATH de usuario
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$binDir*") {
    Write-Host ('  ' + $Cyan + '==>' + $Reset + ' Incorporando ' + $binDir + ' al PATH de usuario de Windows...')
    $newPath = $userPath + ';' + $binDir
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = $env:Path + ';' + $binDir
}

Write-Host ''
Write-Host ('  ' + $Green + $WhiteBold + '[OK] Vork CLI v1.0.3 instalado exitosamente!' + $Reset)
Write-Host ''
Write-Host ('  ' + $WhiteBold + 'Comandos globales disponibles:' + $Reset)
Write-Host ('    ' + $Yellow + 'vork' + $Reset + '                 -> Abre la interfaz interactiva Vork AI')
Write-Host ('    ' + $Yellow + 'vork run <tarea>' + $Reset + '     -> Modo agente autonomo con ejecucion y herramientas')
Write-Host ('    ' + $Yellow + 'vork doctor' + $Reset + '          -> Diagnostico del sistema y proveedores gratuitos')
Write-Host ('    ' + $Yellow + 'vork models' + $Reset + '          -> Estado de modelos disponibles (+20 proveedores)')
Write-Host ('    ' + $Yellow + 'vork translate' + $Reset + '       -> Pilar 01: Traductor en la Nube')
Write-Host ('    ' + $Yellow + 'vork agents' + $Reset + '          -> Pilar 09: Agentes Autonomos')
Write-Host ''
Write-Host ('  ' + $Dim + 'Alias disponibles: vork, vk, vork-cli' + $Reset)
Write-Host ''
